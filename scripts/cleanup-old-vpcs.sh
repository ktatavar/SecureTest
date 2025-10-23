#!/bin/bash

# Script to clean up old/unused VPCs to make room for new infrastructure

set -e

echo "=========================================="
echo "VPC Cleanup Script"
echo "=========================================="
echo ""

# List all VPCs
echo "Current VPCs:"
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],IsDefault]' --output table

echo ""
VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs)' --output text)
echo "Total VPC count: $VPC_COUNT"
echo "VPC limit: 5 (default)"
echo ""

if [ "$VPC_COUNT" -lt 5 ]; then
    echo "✅ VPC count is under limit. No cleanup needed."
    exit 0
fi

echo "⚠️  VPC limit reached!"
echo ""
echo "Options:"
echo "1. Delete unused VPCs (recommended)"
echo "2. Request VPC limit increase from AWS"
echo "3. Use existing VPC for deployment"
echo ""

# Find VPCs without running instances
echo "Checking for VPCs without running instances..."
echo ""

for vpc_id in $(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`false`].VpcId' --output text); do
    VPC_NAME=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --query 'Vpcs[0].Tags[?Key==`Name`].Value' --output text)
    VPC_NAME=${VPC_NAME:-"(unnamed)"}
    
    # Check for running instances
    INSTANCE_COUNT=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=instance-state-name,Values=running" \
        --query 'length(Reservations[].Instances[])' \
        --output text)
    
    # Check for EKS clusters
    EKS_COUNT=$(aws eks list-clusters --query 'length(clusters)' --output text 2>/dev/null || echo "0")
    
    echo "VPC: $vpc_id ($VPC_NAME)"
    echo "  Running instances: $INSTANCE_COUNT"
    
    if [ "$INSTANCE_COUNT" = "0" ]; then
        echo "  ⚠️  This VPC has no running instances"
        echo "  To delete: aws ec2 delete-vpc --vpc-id $vpc_id"
        echo "  (Note: Must delete all dependencies first: subnets, internet gateways, etc.)"
    fi
    echo ""
done

echo "=========================================="
echo "Manual Cleanup Steps"
echo "=========================================="
echo ""
echo "To delete a VPC, you must first delete:"
echo "1. All EC2 instances"
echo "2. All EKS clusters"
echo "3. All NAT gateways"
echo "4. All internet gateways"
echo "5. All subnets"
echo "6. All route tables (except main)"
echo "7. All security groups (except default)"
echo ""
echo "Then run:"
echo "  aws ec2 delete-vpc --vpc-id <VPC_ID>"
echo ""
echo "Or use Terraform to destroy old infrastructure:"
echo "  cd terraform"
echo "  terraform destroy"
echo ""
