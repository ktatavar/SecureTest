#!/bin/bash
# Advanced cleanup script for AWS network dependencies
# This script removes orphaned ENIs, NAT Gateways, and EIPs that block VPC deletion

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "AWS Network Dependencies Cleanup"
echo "=========================================="
echo ""

AWS_REGION=$(aws configure get region || echo "us-east-1")

# Get VPC ID from Terraform or command line
if [ -n "$1" ]; then
    VPC_ID="$1"
elif [ -f terraform/terraform.tfstate ]; then
    VPC_ID=$(cd terraform && terraform output -raw vpc_id 2>/dev/null || echo "")
else
    echo "Usage: $0 <VPC_ID>"
    echo "Or run from project root with terraform.tfstate present"
    exit 1
fi

if [ -z "$VPC_ID" ]; then
    echo -e "${RED}❌ Could not determine VPC ID${NC}"
    exit 1
fi

echo "Cleaning up dependencies for VPC: $VPC_ID"
echo "Region: $AWS_REGION"
echo ""

# Step 1: Delete Load Balancers
echo -e "${BLUE}[1/6] Deleting Load Balancers...${NC}"
echo "-----------------------------------"
LBS=$(aws elbv2 describe-load-balancers --region $AWS_REGION --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)
if [ -n "$LBS" ]; then
    for LB in $LBS; do
        LB_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns $LB --region $AWS_REGION --query 'LoadBalancers[0].LoadBalancerName' --output text)
        echo "  Deleting LoadBalancer: $LB_NAME"
        aws elbv2 delete-load-balancer --load-balancer-arn $LB --region $AWS_REGION
    done
    echo "  Waiting 30 seconds for LoadBalancers to delete..."
    sleep 30
    echo -e "${GREEN}✅ LoadBalancers deleted${NC}"
else
    echo "  No LoadBalancers found"
fi
echo ""

# Step 2: Delete NAT Gateways
echo -e "${BLUE}[2/6] Deleting NAT Gateways...${NC}"
echo "-----------------------------------"
NAT_GWS=$(aws ec2 describe-nat-gateways --region $AWS_REGION --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=pending,available" --query 'NatGateways[*].NatGatewayId' --output text)
if [ -n "$NAT_GWS" ]; then
    for NAT in $NAT_GWS; do
        echo "  Deleting NAT Gateway: $NAT"
        aws ec2 delete-nat-gateway --nat-gateway-id $NAT --region $AWS_REGION
    done
    echo "  Waiting 60 seconds for NAT Gateways to delete..."
    sleep 60
    echo -e "${GREEN}✅ NAT Gateways deleted${NC}"
else
    echo "  No NAT Gateways found"
fi
echo ""

# Step 3: Release Elastic IPs
echo -e "${BLUE}[3/6] Releasing Elastic IPs...${NC}"
echo "-----------------------------------"
# Get all ENIs in the VPC first
ENIS=$(aws ec2 describe-network-interfaces --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text)

# Get EIPs associated with those ENIs
for ENI in $ENIS; do
    ASSOC_ID=$(aws ec2 describe-addresses --region $AWS_REGION --filters "Name=network-interface-id,Values=$ENI" --query 'Addresses[0].AssociationId' --output text 2>/dev/null)
    ALLOC_ID=$(aws ec2 describe-addresses --region $AWS_REGION --filters "Name=network-interface-id,Values=$ENI" --query 'Addresses[0].AllocationId' --output text 2>/dev/null)

    if [ -n "$ASSOC_ID" ] && [ "$ASSOC_ID" != "None" ]; then
        echo "  Disassociating EIP: $ALLOC_ID"
        aws ec2 disassociate-address --association-id $ASSOC_ID --region $AWS_REGION || true
    fi

    if [ -n "$ALLOC_ID" ] && [ "$ALLOC_ID" != "None" ]; then
        echo "  Releasing EIP: $ALLOC_ID"
        aws ec2 release-address --allocation-id $ALLOC_ID --region $AWS_REGION || true
    fi
done

# Also check for unassociated EIPs in the VPC
UNASSOC_EIPS=$(aws ec2 describe-addresses --region $AWS_REGION --filters "Name=domain,Values=vpc" --query 'Addresses[?AssociationId==null].AllocationId' --output text)
if [ -n "$UNASSOC_EIPS" ]; then
    for EIP in $UNASSOC_EIPS; do
        echo "  Releasing unassociated EIP: $EIP"
        aws ec2 release-address --allocation-id $EIP --region $AWS_REGION || true
    done
fi

echo -e "${GREEN}✅ Elastic IPs released${NC}"
echo ""

# Step 4: Delete Network Interfaces (ENIs)
echo -e "${BLUE}[4/6] Deleting Network Interfaces...${NC}"
echo "-----------------------------------"
echo "  Waiting 30 seconds for ENIs to become available..."
sleep 30

ENIS=$(aws ec2 describe-network-interfaces --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]' --output text)
if [ -n "$ENIS" ]; then
    echo "$ENIS" | while read ENI_ID STATUS DESC; do
        # Skip ENIs that are managed by AWS services and will be auto-deleted
        if [[ "$DESC" == *"ELB"* ]] || [[ "$DESC" == *"EKS"* ]] || [[ "$DESC" == *"AWS Lambda"* ]]; then
            echo "  Skipping AWS-managed ENI: $ENI_ID ($DESC)"
            continue
        fi

        if [ "$STATUS" = "in-use" ]; then
            echo "  Detaching ENI: $ENI_ID"
            ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $AWS_REGION --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text)
            if [ -n "$ATTACHMENT_ID" ] && [ "$ATTACHMENT_ID" != "None" ]; then
                aws ec2 detach-network-interface --attachment-id $ATTACHMENT_ID --region $AWS_REGION --force || true
                sleep 5
            fi
        fi

        echo "  Deleting ENI: $ENI_ID"
        aws ec2 delete-network-interface --network-interface-id $ENI_ID --region $AWS_REGION || true
    done

    echo "  Waiting 20 seconds for ENI cleanup..."
    sleep 20
    echo -e "${GREEN}✅ Network Interfaces deleted${NC}"
else
    echo "  No Network Interfaces found"
fi
echo ""

# Step 5: Delete Security Groups (except default)
echo -e "${BLUE}[5/6] Deleting Security Groups...${NC}"
echo "-----------------------------------"
SGS=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
if [ -n "$SGS" ]; then
    # First, remove all rules to break dependencies
    for SG in $SGS; do
        echo "  Removing rules from SG: $SG"
        aws ec2 revoke-security-group-ingress --group-id $SG --ip-permissions "$(aws ec2 describe-security-groups --group-ids $SG --region $AWS_REGION --query 'SecurityGroups[0].IpPermissions' --output json)" --region $AWS_REGION 2>/dev/null || true
        aws ec2 revoke-security-group-egress --group-id $SG --ip-permissions "$(aws ec2 describe-security-groups --group-ids $SG --region $AWS_REGION --query 'SecurityGroups[0].IpPermissionsEgress' --output json)" --region $AWS_REGION 2>/dev/null || true
    done

    # Then delete the security groups
    for SG in $SGS; do
        echo "  Deleting SG: $SG"
        aws ec2 delete-security-group --group-id $SG --region $AWS_REGION || true
    done
    echo -e "${GREEN}✅ Security Groups deleted${NC}"
else
    echo "  No custom Security Groups found"
fi
echo ""

# Step 6: Summary
echo -e "${BLUE}[6/6] Summary${NC}"
echo "-----------------------------------"
echo "Cleaned up network dependencies for VPC: $VPC_ID"
echo ""
echo "Resources removed:"
echo "  ✅ Load Balancers"
echo "  ✅ NAT Gateways"
echo "  ✅ Elastic IPs"
echo "  ✅ Network Interfaces (ENIs)"
echo "  ✅ Security Group rules"
echo ""
echo -e "${GREEN}You can now retry: terraform destroy${NC}"
echo ""
