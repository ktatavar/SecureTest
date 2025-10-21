#!/bin/bash
# Automated setup script for Wiz Technical Exercise
# This script verifies prerequisites and configures the environment

set -e

echo "=========================================="
echo "Wiz Technical Exercise - Automated Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

echo "Step 1: Verifying prerequisites..."
echo "-----------------------------------"

# Check AWS CLI
if command_exists aws; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
    print_status 0 "AWS CLI installed: $AWS_VERSION"
else
    print_status 1 "AWS CLI not found"
    echo "   Install: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    exit 1
fi

# Check Terraform
if command_exists terraform; then
    TF_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    print_status 0 "Terraform installed: v$TF_VERSION"
else
    print_status 1 "Terraform not found"
    echo "   Install: https://www.terraform.io/downloads"
    exit 1
fi

# Check kubectl
if command_exists kubectl; then
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*' | cut -d'"' -f4)
    print_status 0 "kubectl installed: $KUBECTL_VERSION"
else
    print_status 1 "kubectl not found"
    echo "   Install: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check Docker (optional)
if command_exists docker; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    print_status 0 "Docker installed: v$DOCKER_VERSION"
else
    print_status 1 "Docker not found (optional, but recommended)"
    echo "   Install: https://docs.docker.com/get-docker/"
fi

echo ""
echo "Step 2: Verifying AWS credentials..."
echo "------------------------------------"

# Check AWS credentials
if aws sts get-caller-identity >/dev/null 2>&1; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    print_status 0 "AWS credentials configured"
    echo "   Account: $AWS_ACCOUNT_ID"
    echo "   User: $AWS_USER"
else
    print_status 1 "AWS credentials not configured"
    echo "   Run: aws configure"
    exit 1
fi

# Get default region
AWS_REGION=$(aws configure get region || echo "us-east-1")
print_status 0 "AWS Region: $AWS_REGION"

echo ""
echo "Step 3: Configuring Terraform variables..."
echo "-------------------------------------------"

# Create terraform.tfvars if it doesn't exist
if [ -f terraform/terraform.tfvars ]; then
    echo -e "${YELLOW}⚠️  terraform.tfvars already exists. Skipping creation.${NC}"
    echo "   To reconfigure, delete terraform/terraform.tfvars and run this script again."
else
    # Copy template
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars

    # Generate unique S3 bucket name
    UNIQUE_SUFFIX=$(date +%s | tail -c 7)
    S3_BUCKET="mongodb-backups-wiz-${AWS_ACCOUNT_ID}-${UNIQUE_SUFFIX}"

    # Update terraform.tfvars
    sed -i "s/mongodb-backups-wiz-512231857943/${S3_BUCKET}/g" terraform/terraform.tfvars
    sed -i "s/us-east-1/${AWS_REGION}/g" terraform/terraform.tfvars

    # Get Ubuntu 18.04 AMI for the region
    echo "   Looking up Ubuntu 18.04 AMI for region ${AWS_REGION}..."
    UBUNTU_AMI=$(aws ec2 describe-images \
        --region ${AWS_REGION} \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --output text 2>/dev/null || echo "")

    if [ -n "$UBUNTU_AMI" ]; then
        sed -i "s|# mongodb_ami_id.*|mongodb_ami_id = \"${UBUNTU_AMI}\"|g" terraform/terraform.tfvars
        echo "   Found Ubuntu 18.04 AMI: ${UBUNTU_AMI}"
    else
        echo -e "${YELLOW}   ⚠️  Could not auto-detect AMI. You may need to set it manually.${NC}"
    fi

    print_status 0 "terraform.tfvars created and configured"
    echo "   S3 Bucket: $S3_BUCKET"
    echo "   Region: $AWS_REGION"
fi

echo ""
echo "Step 4: Updating Kubernetes manifests..."
echo "-----------------------------------------"

# Update deployment.yaml with correct AWS account ID
if [ -f k8s/deployment.yaml ]; then
    sed -i "s/512231857943/${AWS_ACCOUNT_ID}/g" k8s/deployment.yaml
    print_status 0 "Updated k8s/deployment.yaml with AWS Account ID"
fi

echo ""
echo "Step 5: Creating helper scripts..."
echo "-----------------------------------"

# Create .env file for easy reference
cat > .env << EOF
# Auto-generated environment variables
export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
export AWS_REGION=${AWS_REGION}
export TF_VAR_aws_region=${AWS_REGION}
EOF

print_status 0 "Created .env file with environment variables"

echo ""
echo "=========================================="
echo "Setup Complete! ✅"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Review terraform/terraform.tfvars for any custom settings"
echo "  2. Deploy infrastructure:"
echo "     cd terraform && terraform init && terraform apply"
echo "  3. Or use the automated deployment:"
echo "     ./scripts/deploy-all.sh"
echo ""
echo "To load environment variables in current shell:"
echo "  source .env"
echo ""
