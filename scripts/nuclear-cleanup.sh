#!/bin/bash
# NUCLEAR CLEANUP - Force delete all AWS resources
# Use this when normal cleanup fails and you don't care about graceful shutdown

set +e  # Don't exit on errors

VPC_ID="${1:-vpc-077547942666da22f}"
REGION="${2:-us-east-1}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "⚠️  NUCLEAR CLEANUP MODE ⚠️"
echo "=========================================="
echo ""
echo "VPC ID: $VPC_ID"
echo "Region: $REGION"
echo ""
echo "This will FORCE DELETE everything!"
echo "No prompts. No waiting. Just destruction."
echo ""
read -p "Type 'DESTROY' to continue: " CONFIRM

if [ "$CONFIRM" != "DESTROY" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "🔥 Starting nuclear cleanup..."
echo ""

# Step 1: Delete ALL Load Balancers in VPC
echo -e "${BLUE}[1/10] Nuking Load Balancers...${NC}"
aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text | \
xargs -I {} aws elbv2 delete-load-balancer --load-balancer-arn {} --region $REGION 2>/dev/null
echo "   Deleted Load Balancers"

# Also classic ELBs
aws elb describe-load-balancers --region $REGION --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text | \
xargs -I {} aws elb delete-load-balancer --load-balancer-name {} --region $REGION 2>/dev/null
echo "   Deleted Classic Load Balancers"

# Step 2: Delete ALL Target Groups
echo -e "${BLUE}[2/10] Deleting Target Groups...${NC}"
aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" --output text | \
xargs -I {} aws elbv2 delete-target-group --target-group-arn {} --region $REGION 2>/dev/null
echo "   Deleted Target Groups"

# Step 3: Delete ALL NAT Gateways
echo -e "${BLUE}[3/10] Nuking NAT Gateways...${NC}"
aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[*].NatGatewayId' --output text | \
xargs -I {} aws ec2 delete-nat-gateway --nat-gateway-id {} --region $REGION 2>/dev/null
echo "   Deleted NAT Gateways"

# Step 4: Force detach and delete ALL ENIs
echo -e "${BLUE}[4/10] Force deleting ALL Network Interfaces...${NC}"
aws ec2 describe-network-interfaces --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text | \
while read -r ENI; do
    if [ -n "$ENI" ]; then
        # Get attachment ID
        ATTACHMENT=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI --region $REGION --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null)

        # Force detach if attached
        if [ -n "$ATTACHMENT" ] && [ "$ATTACHMENT" != "None" ]; then
            aws ec2 detach-network-interface --attachment-id $ATTACHMENT --region $REGION --force 2>/dev/null
            echo "   Detached: $ENI"
            sleep 2
        fi

        # Delete ENI
        aws ec2 delete-network-interface --network-interface-id $ENI --region $REGION 2>/dev/null
        echo "   Deleted: $ENI"
    fi
done

# Step 5: Release ALL Elastic IPs
echo -e "${BLUE}[5/10] Releasing ALL Elastic IPs...${NC}"
aws ec2 describe-addresses --region $REGION --query 'Addresses[*].[AllocationId,AssociationId]' --output text | \
while read -r ALLOC_ID ASSOC_ID; do
    if [ -n "$ALLOC_ID" ]; then
        # Disassociate if associated
        if [ -n "$ASSOC_ID" ] && [ "$ASSOC_ID" != "None" ]; then
            aws ec2 disassociate-address --association-id $ASSOC_ID --region $REGION 2>/dev/null
            echo "   Disassociated: $ALLOC_ID"
        fi

        # Release EIP
        aws ec2 release-address --allocation-id $ALLOC_ID --region $REGION 2>/dev/null
        echo "   Released: $ALLOC_ID"
    fi
done

# Step 6: Wait for everything to propagate
echo -e "${BLUE}[6/10] Waiting for AWS to catch up (60 seconds)...${NC}"
for i in {60..1}; do
    echo -ne "   $i seconds remaining...\r"
    sleep 1
done
echo ""

# Step 7: Delete ALL Security Group rules
echo -e "${BLUE}[7/10] Removing ALL Security Group rules...${NC}"
aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text | \
while read -r SG; do
    if [ -n "$SG" ]; then
        # Remove all ingress rules
        aws ec2 describe-security-groups --group-ids $SG --region $REGION --query 'SecurityGroups[0].IpPermissions' --output json | \
        jq -r 'if . != null and . != [] then . else empty end' | \
        xargs -0 -I {} aws ec2 revoke-security-group-ingress --group-id $SG --ip-permissions '{}' --region $REGION 2>/dev/null

        # Remove all egress rules
        aws ec2 describe-security-groups --group-ids $SG --region $REGION --query 'SecurityGroups[0].IpPermissionsEgress' --output json | \
        jq -r 'if . != null and . != [] then . else empty end' | \
        xargs -0 -I {} aws ec2 revoke-security-group-egress --group-id $SG --ip-permissions '{}' --region $REGION 2>/dev/null

        echo "   Cleaned rules: $SG"
    fi
done

# Step 8: Delete ALL non-default Security Groups
echo -e "${BLUE}[8/10] Deleting Security Groups...${NC}"
aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text | \
xargs -I {} aws ec2 delete-security-group --group-id {} --region $REGION 2>/dev/null
echo "   Deleted Security Groups"

# Step 9: Terminate ALL EC2 instances in VPC
echo -e "${BLUE}[9/10] Terminating ALL EC2 instances...${NC}"
aws ec2 describe-instances --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,stopped" --query 'Reservations[*].Instances[*].InstanceId' --output text | \
xargs -I {} aws ec2 terminate-instances --instance-ids {} --region $REGION 2>/dev/null
echo "   Terminated EC2 instances"

# Step 10: One more wait for everything to settle
echo -e "${BLUE}[10/10] Final wait for AWS cleanup (30 seconds)...${NC}"
for i in {30..1}; do
    echo -ne "   $i seconds remaining...\r"
    sleep 1
done
echo ""

echo ""
echo "=========================================="
echo "☢️  Nuclear cleanup phase complete!"
echo "=========================================="
echo ""
echo -e "${YELLOW}Now run Terraform destroy:${NC}"
echo ""
echo "  cd terraform"
echo "  terraform destroy -auto-approve"
echo ""
echo -e "${YELLOW}If Terraform still fails, wait 5 minutes and try again.${NC}"
echo "AWS needs time to fully clean up all dependencies."
echo ""
