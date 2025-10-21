#!/bin/bash
# Complete cleanup script for Wiz Technical Exercise
# This script removes all deployed resources

set -e

echo "=========================================="
echo "Wiz Technical Exercise - Complete Cleanup"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get AWS profile if set
AWS_PROFILE=${AWS_PROFILE:-default}
if [ "$AWS_PROFILE" != "default" ]; then
    echo "Using AWS Profile: $AWS_PROFILE"
    export AWS_DEFAULT_PROFILE=$AWS_PROFILE
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
AWS_REGION=$(aws configure get region || echo "us-east-1")

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}❌ Cannot determine AWS account. Please configure AWS credentials.${NC}"
    exit 1
fi

echo "Cleanup Configuration:"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  AWS Region: $AWS_REGION"
echo "  AWS Profile: $AWS_PROFILE"
echo ""

echo -e "${YELLOW}⚠️  WARNING: This will DELETE all resources!${NC}"
echo ""
echo "Resources that will be deleted:"
echo "  • Kubernetes namespace and all resources"
echo "  • EKS cluster and node groups"
echo "  • MongoDB EC2 instance"
echo "  • VPC, subnets, and networking"
echo "  • S3 bucket and backups (if empty)"
echo "  • IAM roles and policies"
echo "  • ECR repository images"
echo ""

read -p "Are you sure you want to continue? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

START_TIME=$(date +%s)

# Step 1: Delete Kubernetes resources
echo "[1/4] Deleting Kubernetes resources..."
echo "---------------------------------------"

if kubectl get namespace todo-app >/dev/null 2>&1; then
    echo "Deleting namespace todo-app..."
    kubectl delete namespace todo-app --wait=true --timeout=300s || {
        echo -e "${YELLOW}⚠️  Timeout waiting for namespace deletion. Continuing...${NC}"
        kubectl delete namespace todo-app --grace-period=0 --force || true
    }
    echo -e "${GREEN}✅ Kubernetes resources deleted${NC}"
else
    echo "ℹ️  Namespace todo-app not found. Skipping."
fi

echo ""

# Step 2: Wait for LoadBalancers to be deleted
echo "[2/4] Waiting for LoadBalancers to be deleted..."
echo "-------------------------------------------------"
echo "⏱️  Waiting 60 seconds for AWS LoadBalancers to be fully removed..."
echo "   (This prevents Terraform errors due to resources in use)"
sleep 60
echo -e "${GREEN}✅ LoadBalancers should be deleted${NC}"
echo ""

# Step 3: Delete ECR images (optional)
echo "[3/4] Cleaning up ECR repository..."
echo "------------------------------------"

if aws ecr describe-repositories --repository-names todo-app --region $AWS_REGION >/dev/null 2>&1; then
    read -p "Delete ECR repository and all images? (yes/no): " -r
    echo ""
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Deleting ECR repository..."
        aws ecr delete-repository --repository-name todo-app --region $AWS_REGION --force || {
            echo -e "${YELLOW}⚠️  Could not delete ECR repository. It may contain images.${NC}"
            echo "   To delete manually: aws ecr delete-repository --repository-name todo-app --region $AWS_REGION --force"
        }
        echo -e "${GREEN}✅ ECR repository deleted${NC}"
    else
        echo "ℹ️  Skipping ECR repository deletion."
    fi
else
    echo "ℹ️  ECR repository not found. Skipping."
fi

echo ""

# Step 4: Destroy Terraform infrastructure
echo "[4/4] Destroying Terraform infrastructure..."
echo "---------------------------------------------"

cd terraform 2>/dev/null || cd ../terraform 2>/dev/null || {
    echo -e "${RED}❌ terraform directory not found${NC}"
    exit 1
}

if [ ! -f terraform.tfstate ] && [ ! -f terraform.tfstate.backup ]; then
    echo -e "${YELLOW}⚠️  No Terraform state found. Nothing to destroy.${NC}"
    cd ..
else
    # Get S3 bucket name before destroying
    S3_BUCKET=$(terraform output -raw mongodb_backup_bucket 2>/dev/null || echo "")

    echo "Running terraform destroy..."
    echo "⏱️  This will take approximately 10-15 minutes..."
    echo ""

    terraform destroy -auto-approve || {
        echo -e "${RED}❌ Terraform destroy failed!${NC}"
        echo ""
        echo "Common issues:"
        echo "  1. LoadBalancer still exists - wait a few minutes and retry"
        echo "  2. ENIs still attached - wait for cleanup and retry"
        echo "  3. Resources created outside Terraform - delete manually"
        echo ""
        echo "To retry: cd terraform && terraform destroy"
        exit 1
    }

    echo -e "${GREEN}✅ Terraform infrastructure destroyed${NC}"
    cd ..

    # Clean up S3 bucket if it still exists
    if [ -n "$S3_BUCKET" ]; then
        echo ""
        echo "Checking S3 bucket..."
        if aws s3 ls s3://${S3_BUCKET} >/dev/null 2>&1; then
            read -p "S3 bucket still exists. Delete bucket and all backups? (yes/no): " -r
            echo ""
            if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                echo "Emptying S3 bucket..."
                aws s3 rm s3://${S3_BUCKET} --recursive --region $AWS_REGION
                echo "Deleting S3 bucket..."
                aws s3 rb s3://${S3_BUCKET} --region $AWS_REGION || {
                    echo -e "${YELLOW}⚠️  Could not delete S3 bucket. Delete manually:${NC}"
                    echo "   aws s3 rb s3://${S3_BUCKET} --force --region $AWS_REGION"
                }
                echo -e "${GREEN}✅ S3 bucket deleted${NC}"
            else
                echo "ℹ️  S3 bucket retained: ${S3_BUCKET}"
            fi
        fi
    fi
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "=========================================="
echo "🧹 Cleanup Complete!"
echo "=========================================="
echo ""
echo "⏱️  Total cleanup time: ${MINUTES}m ${SECONDS}s"
echo ""
echo "All resources have been removed."
echo ""
echo "Verification commands:"
echo "  aws eks list-clusters --region $AWS_REGION"
echo "  aws ec2 describe-instances --region $AWS_REGION --filters 'Name=tag:Project,Values=wiz-exercise'"
echo "  aws s3 ls | grep wiz-exercise"
echo ""
echo "Local cleanup (optional):"
echo "  rm -rf terraform/.terraform"
echo "  rm -f terraform/terraform.tfstate*"
echo "  rm -f terraform/.terraform.lock.hcl"
echo "  rm -f outputs.txt .env"
echo ""
echo "=========================================="
