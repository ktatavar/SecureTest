#!/bin/bash

# Script to import existing AWS resources into Terraform state
# This allows Terraform to manage resources that were created outside of Terraform

set -e

echo "=========================================="
echo "Importing Existing Resources to Terraform"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# Initialize Terraform
echo "Initializing Terraform..."
terraform init -upgrade
echo ""

# Import existing resources
echo "=========================================="
echo "Importing Existing Resources"
echo "=========================================="
echo ""

# 1. IAM Policy - GitHubActionsTerraformPolicy
echo "1. Checking IAM Policy: GitHubActionsTerraformPolicy"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/GitHubActionsTerraformPolicy"
if aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    echo "   Policy exists, but using data source (no import needed)"
else
    echo "   Policy does not exist"
fi
echo ""

# 2. MongoDB IAM Role
echo "2. Checking IAM Role: mongodb-vm-role"
if aws iam get-role --role-name mongodb-vm-role &>/dev/null; then
    echo "   Role exists, importing..."
    terraform import 'aws_iam_role.mongodb_vm' mongodb-vm-role 2>/dev/null || echo "   Already imported or error"
else
    echo "   Role does not exist, will be created"
fi
echo ""

# 3. S3 Bucket
echo "3. Checking S3 Bucket: mongodb-backups-insecure-unique-12345"
if aws s3api head-bucket --bucket mongodb-backups-insecure-unique-12345 2>/dev/null; then
    echo "   Bucket exists, importing..."
    terraform import 'aws_s3_bucket.mongodb_backups' mongodb-backups-insecure-unique-12345 2>/dev/null || echo "   Already imported or error"
else
    echo "   Bucket does not exist, will be created"
fi
echo ""

# 4. KMS Key Alias
echo "4. Checking KMS Alias: alias/eks/wiz-exercise-cluster"
if aws kms describe-key --key-id alias/eks/wiz-exercise-cluster &>/dev/null; then
    echo "   KMS alias exists"
    KEY_ID=$(aws kms describe-key --key-id alias/eks/wiz-exercise-cluster --query 'KeyMetadata.KeyId' --output text)
    echo "   Key ID: $KEY_ID"
    # Note: KMS aliases are tricky to import, may need manual handling
    echo "   ⚠️  KMS resources may need manual import or recreation"
else
    echo "   KMS alias does not exist, will be created"
fi
echo ""

# 5. CloudWatch Log Group
echo "5. Checking CloudWatch Log Group: /aws/eks/wiz-exercise-cluster/cluster"
if aws logs describe-log-groups --log-group-name-prefix "/aws/eks/wiz-exercise-cluster/cluster" --query 'logGroups[0]' &>/dev/null; then
    echo "   Log group exists, importing..."
    terraform import 'module.eks.aws_cloudwatch_log_group.this[0]' /aws/eks/wiz-exercise-cluster/cluster 2>/dev/null || echo "   Already imported or error"
else
    echo "   Log group does not exist, will be created"
fi
echo ""

# 6. VPC
echo "6. Checking VPCs..."
VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs)' --output text)
echo "   Current VPC count: $VPC_COUNT"
if [ "$VPC_COUNT" -ge 5 ]; then
    echo "   ⚠️  VPC limit reached! Cannot create new VPC."
    echo "   Options:"
    echo "     a) Delete unused VPCs"
    echo "     b) Use existing VPC (modify Terraform to use data source)"
    echo "     c) Request VPC limit increase"
fi
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Review import results above"
echo "2. For VPC limit: Either delete unused VPCs or use existing VPC"
echo "3. Run: terraform plan"
echo "4. Run: terraform apply"
echo ""
