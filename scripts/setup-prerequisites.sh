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
BLUE='\033[0;34m'
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
    AWS_VERSION=$(aws --version 2>&1 | awk '{print $1}')
    print_status 0 "AWS CLI installed: $AWS_VERSION"
else
    print_status 1 "AWS CLI not found"
    echo "   Install: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    exit 1
fi

# Check Terraform
if command_exists terraform; then
    TF_VERSION=$(terraform version | head -1 | awk '{print $2}')
    print_status 0 "Terraform installed: $TF_VERSION"
else
    print_status 1 "Terraform not found"
    echo "   Install: https://www.terraform.io/downloads"
    exit 1
fi

# Check kubectl
if command_exists kubectl; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | awk '{print $3}' || echo "installed")
    print_status 0 "kubectl installed: $KUBECTL_VERSION"
else
    print_status 1 "kubectl not found"
    echo "   Install: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check Docker (optional)
if command_exists docker; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    print_status 0 "Docker installed: v$DOCKER_VERSION"
else
    echo -e "${YELLOW}⚠️  Docker not found (optional, but recommended)${NC}"
    echo "   Install: https://docs.docker.com/get-docker/"
fi

echo ""
echo "Step 2: Checking AWS credentials..."
echo "------------------------------------"

# Check AWS credentials
if aws sts get-caller-identity >/dev/null 2>&1; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    AWS_REGION=$(aws configure get region || echo "us-east-1")

    print_status 0 "AWS credentials configured"
    echo "   Account ID: $AWS_ACCOUNT_ID"
    echo "   User: $AWS_USER"
    echo "   Region: $AWS_REGION"
else
    print_status 1 "AWS credentials not configured"
    echo "   Run: aws configure"
    exit 1
fi

echo ""
echo "Step 3: Checking current configuration..."
echo "------------------------------------------"

# Check if terraform.tfvars exists
if [ -f terraform/terraform.tfvars ]; then
    echo -e "${BLUE}📋 Existing terraform.tfvars found${NC}"
    echo ""

    # Extract current values
    CURRENT_REGION=$(grep '^aws_region' terraform/terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "not set")
    CURRENT_BUCKET=$(grep '^mongodb_backup_bucket' terraform/terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "not set")
    CURRENT_PROJECT=$(grep '^project_name' terraform/terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "wiz-exercise")
    CURRENT_ENV=$(grep '^environment' terraform/terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "dev")

    echo "Current Terraform Settings:"
    echo "   AWS Region: $CURRENT_REGION"
    echo "   Project Name: $CURRENT_PROJECT"
    echo "   Environment: $CURRENT_ENV"
    echo "   S3 Bucket: $CURRENT_BUCKET"
    echo ""

    # Check if settings match current AWS account
    if [ "$CURRENT_REGION" = "$AWS_REGION" ]; then
        echo -e "${GREEN}✅ Region matches AWS CLI configuration${NC}"
    else
        echo -e "${YELLOW}⚠️  Region mismatch: terraform.tfvars ($CURRENT_REGION) vs AWS CLI ($AWS_REGION)${NC}"
    fi

    # Ask if user wants to keep existing config
    read -p "Do you want to keep the existing configuration? (yes/no): " -r KEEP_CONFIG
    echo ""

    if [[ $KEEP_CONFIG =~ ^[Yy][Ee][Ss]$|^[Yy]$ ]]; then
        echo -e "${GREEN}✅ Keeping existing terraform.tfvars${NC}"
        SKIP_TFVARS_UPDATE=true
    else
        echo -e "${YELLOW}⚠️  Will update terraform.tfvars with current AWS settings${NC}"
        SKIP_TFVARS_UPDATE=false
    fi
else
    echo -e "${YELLOW}📋 No terraform.tfvars found - will create new one${NC}"
    SKIP_TFVARS_UPDATE=false
fi

echo ""
echo "Step 4: Configuring Terraform variables..."
echo "-------------------------------------------"

if [ "$SKIP_TFVARS_UPDATE" = "false" ]; then
    # Backup existing file if it exists
    if [ -f terraform/terraform.tfvars ]; then
        BACKUP_FILE="terraform/terraform.tfvars.backup.$(date +%Y%m%d_%H%M%S)"
        cp terraform/terraform.tfvars "$BACKUP_FILE"
        echo "   Backed up existing file to: $BACKUP_FILE"
    fi

    # Copy template
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars

    # Generate unique S3 bucket name
    UNIQUE_SUFFIX=$(date +%s | tail -c 7)
    S3_BUCKET="mongodb-backups-wiz-${AWS_ACCOUNT_ID}-${UNIQUE_SUFFIX}"

    # Update terraform.tfvars with current AWS settings
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/mongodb-backups-wiz-512231857943/${S3_BUCKET}/g" terraform/terraform.tfvars
        sed -i '' "s/us-east-1/${AWS_REGION}/g" terraform/terraform.tfvars
    else
        # Linux
        sed -i "s/mongodb-backups-wiz-512231857943/${S3_BUCKET}/g" terraform/terraform.tfvars
        sed -i "s/us-east-1/${AWS_REGION}/g" terraform/terraform.tfvars
    fi

    # Get Ubuntu 18.04 AMI for the region
    echo "   Looking up Ubuntu 18.04 AMI for region ${AWS_REGION}..."
    UBUNTU_AMI=$(aws ec2 describe-images \
        --region ${AWS_REGION} \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --output text 2>/dev/null || echo "")

    if [ -n "$UBUNTU_AMI" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|# mongodb_ami_id.*|mongodb_ami_id = \"${UBUNTU_AMI}\"|g" terraform/terraform.tfvars
        else
            sed -i "s|# mongodb_ami_id.*|mongodb_ami_id = \"${UBUNTU_AMI}\"|g" terraform/terraform.tfvars
        fi
        echo "   Found Ubuntu 18.04 AMI: ${UBUNTU_AMI}"
    else
        echo -e "${YELLOW}   ⚠️  Could not auto-detect AMI. You may need to set it manually.${NC}"
    fi

    print_status 0 "terraform.tfvars configured"
    echo "   S3 Bucket: $S3_BUCKET"
    echo "   Region: $AWS_REGION"
    echo "   AMI: ${UBUNTU_AMI:-manually set required}"
else
    # Using existing configuration
    CURRENT_BUCKET=$(grep '^mongodb_backup_bucket' terraform/terraform.tfvars | cut -d'"' -f2 2>/dev/null)
    echo "   Using existing S3 Bucket: $CURRENT_BUCKET"
    echo "   Using existing Region: $CURRENT_REGION"
fi

echo ""
echo "Step 5: Updating Kubernetes manifests..."
echo "-----------------------------------------"

# Check current account ID in deployment.yaml
if [ -f k8s/deployment.yaml ]; then
    CURRENT_K8S_ACCOUNT=$(grep 'dkr.ecr' k8s/deployment.yaml | grep -o '[0-9]\{12\}' | head -1 2>/dev/null || echo "")

    if [ "$CURRENT_K8S_ACCOUNT" = "$AWS_ACCOUNT_ID" ]; then
        echo -e "${GREEN}✅ k8s/deployment.yaml already has correct AWS Account ID${NC}"
    else
        if [ -n "$CURRENT_K8S_ACCOUNT" ]; then
            echo "   Updating AWS Account ID: $CURRENT_K8S_ACCOUNT → $AWS_ACCOUNT_ID"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/${CURRENT_K8S_ACCOUNT}/${AWS_ACCOUNT_ID}/g" k8s/deployment.yaml
            else
                sed -i "s/${CURRENT_K8S_ACCOUNT}/${AWS_ACCOUNT_ID}/g" k8s/deployment.yaml
            fi
        else
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/512231857943/${AWS_ACCOUNT_ID}/g" k8s/deployment.yaml
            else
                sed -i "s/512231857943/${AWS_ACCOUNT_ID}/g" k8s/deployment.yaml
            fi
        fi
        print_status 0 "Updated k8s/deployment.yaml with AWS Account ID: $AWS_ACCOUNT_ID"
    fi
fi

echo ""
echo "Step 6: Creating environment file..."
echo "-------------------------------------"

# Check if .env exists and show current values
if [ -f .env ]; then
    echo -e "${BLUE}📋 Existing .env file found${NC}"
    EXISTING_ACCOUNT=$(grep AWS_ACCOUNT_ID .env | cut -d'=' -f2 2>/dev/null || echo "")
    EXISTING_REGION=$(grep AWS_REGION .env | cut -d'=' -f2 2>/dev/null || echo "")

    if [ "$EXISTING_ACCOUNT" = "$AWS_ACCOUNT_ID" ] && [ "$EXISTING_REGION" = "$AWS_REGION" ]; then
        echo -e "${GREEN}✅ .env file already up to date${NC}"
    else
        echo "   Updating .env with current AWS settings"
    fi
fi

# Create/update .env file
cat > .env << EOF
# Auto-generated environment variables
# Generated: $(date)
export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
export AWS_REGION=${AWS_REGION}
export TF_VAR_aws_region=${AWS_REGION}
EOF

print_status 0 "Created .env file with environment variables"

echo ""
echo "=========================================="
echo "🎉 Setup Complete!"
echo "=========================================="
echo ""
echo -e "${BLUE}📊 Current Configuration Summary:${NC}"
echo "-----------------------------------"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  AWS Region: $AWS_REGION"
echo "  Terraform Config: terraform/terraform.tfvars"
echo "  Environment File: .env"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "-----------------------------------"
echo "  1. Review configuration:"
echo "     cat terraform/terraform.tfvars"
echo ""
echo "  2. Load environment variables:"
echo "     source .env"
echo ""
echo "  3. Deploy infrastructure (choose one):"
echo ""
echo "     Option A - Automated (25-40 min):"
echo "     ./scripts/deploy-all.sh"
echo ""
echo "     Option B - Manual:"
echo "     cd terraform"
echo "     terraform init"
echo "     terraform plan"
echo "     terraform apply"
echo ""
echo "  4. Verify deployment:"
echo "     ./scripts/verify-security-issues.sh"
echo ""
echo "=========================================="
echo ""
