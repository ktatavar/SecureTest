#!/bin/bash

# One-time setup script to grant GitHub Actions IAM role full permissions
# This allows the role to run Terraform and manage all AWS resources

set -e

echo "=========================================="
echo "GitHub Actions IAM Role Setup"
echo "=========================================="
echo ""

ROLE_NAME="GitHubActionsECRRole"

# Check if role exists
echo "Checking if role exists..."
if ! aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    echo "❌ Role $ROLE_NAME not found!"
    echo ""
    echo "Available roles with 'GitHub' or 'Actions' in name:"
    aws iam list-roles --query 'Roles[?contains(RoleName, `GitHub`) || contains(RoleName, `Actions`)].RoleName' --output table
    echo ""
    echo "Please update ROLE_NAME in this script with the correct role name."
    exit 1
fi

echo "✅ Found role: $ROLE_NAME"
echo ""

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# Attach AWS managed policies
echo "=========================================="
echo "Attaching AWS Managed Policies"
echo "=========================================="
echo ""

echo "1. Attaching PowerUserAccess..."
echo "   (Allows all AWS services except IAM management)"
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/PowerUserAccess" 2>/dev/null || echo "   Already attached or error occurred"

echo "✅ PowerUserAccess attached"
echo ""

echo "2. Attaching IAMFullAccess..."
echo "   (Allows full IAM management for EKS, roles, policies)"
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/IAMFullAccess" 2>/dev/null || echo "   Already attached or error occurred"

echo "✅ IAMFullAccess attached"
echo ""

# Verify attached policies
echo "=========================================="
echo "Verification: Attached Policies"
echo "=========================================="
echo ""
aws iam list-attached-role-policies --role-name "$ROLE_NAME" --output table

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "The GitHub Actions role now has permissions to:"
echo ""
echo "  ✅ Run Terraform apply/destroy"
echo "  ✅ Create and manage EKS clusters"
echo "  ✅ Create and manage IAM roles/policies"
echo "  ✅ Create and manage EC2 instances, VPCs, security groups"
echo "  ✅ Push/pull container images to/from ECR"
echo "  ✅ Create and manage S3 buckets"
echo "  ✅ Create and manage CloudWatch log groups"
echo "  ✅ Create and manage KMS keys"
echo "  ✅ Create and manage Load Balancers"
echo "  ✅ Create and manage Auto Scaling groups"
echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Commit and push the Terraform IAM policy code:"
echo "   cd /Users/kalyantatavarti/gitlocal/SecureTest"
echo "   git add terraform/github-actions-role.tf"
echo "   git commit -m 'Add Terraform-managed IAM policy'"
echo "   git push origin main"
echo ""
echo "2. Run Pipeline 1 (Infrastructure):"
echo "   gh workflow run terraform-deploy.yml -f action=apply"
echo ""
echo "3. Run Pipeline 2 (Application):"
echo "   gh workflow run app-deploy.yml -f environment=dev"
echo ""
echo "=========================================="
echo "Security Note"
echo "=========================================="
echo ""
echo "⚠️  This role has broad permissions (PowerUserAccess + IAMFullAccess)"
echo "    This is necessary for Terraform to manage infrastructure."
echo ""
echo "    In production, consider:"
echo "    - Using separate roles for different environments"
echo "    - Implementing least-privilege policies"
echo "    - Adding SCPs (Service Control Policies)"
echo "    - Enabling CloudTrail for audit logging"
echo ""
