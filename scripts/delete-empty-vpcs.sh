#!/bin/bash

# Script to automatically delete empty VPCs and their dependencies

set -e

echo "=========================================="
echo "Delete Empty VPCs"
echo "=========================================="
echo ""

delete_vpc_dependencies() {
    local vpc_id=$1
    echo "Cleaning up VPC: $vpc_id"
    
    # Delete NAT Gateways
    echo "  Deleting NAT Gateways..."
    for nat_id in $(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[*].NatGatewayId' --output text); do
        echo "    Deleting NAT Gateway: $nat_id"
        aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id"
    done
    
    # Wait for NAT gateways to be deleted
    sleep 10
    
    # Release Elastic IPs
    echo "  Releasing Elastic IPs..."
    for alloc_id in $(aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --query 'Addresses[*].AllocationId' --output text); do
        # Check if EIP is associated with this VPC
        echo "    Releasing EIP: $alloc_id"
        aws ec2 release-address --allocation-id "$alloc_id" 2>/dev/null || true
    done
    
    # Delete Internet Gateways
    echo "  Deleting Internet Gateways..."
    for igw_id in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[*].InternetGatewayId' --output text); do
        echo "    Detaching and deleting IGW: $igw_id"
        aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id"
        aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id"
    done
    
    # Delete Subnets
    echo "  Deleting Subnets..."
    for subnet_id in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].SubnetId' --output text); do
        echo "    Deleting subnet: $subnet_id"
        aws ec2 delete-subnet --subnet-id "$subnet_id"
    done
    
    # Delete Route Tables (except main)
    echo "  Deleting Route Tables..."
    for rt_id in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' --output text); do
        echo "    Deleting route table: $rt_id"
        aws ec2 delete-route-table --route-table-id "$rt_id"
    done
    
    # Delete Security Groups (except default)
    echo "  Deleting Security Groups..."
    for sg_id in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
        echo "    Deleting security group: $sg_id"
        aws ec2 delete-security-group --group-id "$sg_id" 2>/dev/null || true
    done
    
    # Delete VPC
    echo "  Deleting VPC..."
    aws ec2 delete-vpc --vpc-id "$vpc_id"
    echo "  ✅ VPC $vpc_id deleted!"
    echo ""
}

# Find and delete empty VPCs
echo "Finding empty VPCs..."
echo ""

DELETED_COUNT=0

for vpc_id in $(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`false`].VpcId' --output text); do
    VPC_NAME=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --query 'Vpcs[0].Tags[?Key==`Name`].Value' --output text)
    VPC_NAME=${VPC_NAME:-"(unnamed)"}
    
    # Check for running instances
    INSTANCE_COUNT=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=instance-state-name,Values=running" \
        --query 'length(Reservations[].Instances[])' \
        --output text)
    
    if [ "$INSTANCE_COUNT" = "0" ]; then
        echo "Found empty VPC: $vpc_id ($VPC_NAME)"
        echo "Deleting..."
        delete_vpc_dependencies "$vpc_id"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    else
        echo "Skipping VPC $vpc_id ($VPC_NAME) - has $INSTANCE_COUNT running instances"
    fi
done

echo "=========================================="
echo "✅ Cleanup Complete!"
echo "=========================================="
echo ""
echo "Deleted $DELETED_COUNT VPC(s)"
echo ""

# Show remaining VPCs
echo "Remaining VPCs:"
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],IsDefault]' --output table

VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs)' --output text)
echo ""
echo "Total VPC count: $VPC_COUNT / 5"
echo ""

if [ "$VPC_COUNT" -lt 5 ]; then
    echo "✅ VPC limit no longer reached! Ready to create new infrastructure."
else
    echo "⚠️  VPC limit still reached. May need to delete more VPCs or use existing one."
fi
