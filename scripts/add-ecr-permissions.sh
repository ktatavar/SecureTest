#!/bin/bash

# Script to add ECR permissions to GitHub Actions IAM role

set -e

echo "=========================================="
echo "Adding ECR Permissions to IAM Role"
echo "=========================================="
echo ""

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# Define role name (adjust if your role has a different name)
ROLE_NAME="GitHubActionsRole"
echo "IAM Role: $ROLE_NAME"
echo ""

# Check if role exists
if ! aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    echo "❌ Role $ROLE_NAME not found!"
    echo ""
    echo "Available roles:"
    aws iam list-roles --query 'Roles[?contains(RoleName, `GitHub`) || contains(RoleName, `Actions`)].RoleName' --output table
    echo ""
    echo "Please update ROLE_NAME in this script with the correct role name."
    exit 1
fi

echo "✅ Role found: $ROLE_NAME"
echo ""

# Option 1: Attach AWS managed policy (easiest)
echo "Option 1: Attaching AWS managed ECR policy..."
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"

echo "✅ Attached AmazonEC2ContainerRegistryPowerUser policy"
echo ""

# Option 2: Create and attach custom policy (more granular)
echo "Option 2: Creating custom ECR policy..."
POLICY_NAME="GitHubActionsECRPolicy"

# Check if policy already exists
EXISTING_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -n "$EXISTING_POLICY_ARN" ]; then
    echo "Policy $POLICY_NAME already exists: $EXISTING_POLICY_ARN"
    echo "Attaching to role..."
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "$EXISTING_POLICY_ARN"
else
    echo "Creating new policy: $POLICY_NAME"
    POLICY_ARN=$(aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document file://iam-policies/github-actions-ecr-policy.json \
        --description "ECR permissions for GitHub Actions" \
        --query 'Policy.Arn' \
        --output text)
    
    echo "✅ Created policy: $POLICY_ARN"
    echo ""
    
    echo "Attaching policy to role..."
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "$POLICY_ARN"
fi

echo "✅ Custom ECR policy attached"
echo ""

# Verify attached policies
echo "=========================================="
echo "Attached Policies:"
echo "=========================================="
aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[*].[PolicyName,PolicyArn]' --output table

echo ""
echo "=========================================="
echo "✅ ECR Permissions Added Successfully!"
echo "=========================================="
echo ""
echo "The IAM role now has permissions to:"
echo "  ✅ Create ECR repositories"
echo "  ✅ Push/pull container images"
echo "  ✅ Manage image scanning"
echo "  ✅ Manage lifecycle policies"
echo ""
echo "You can now re-run the GitHub Actions workflow!"
