#!/bin/bash
# Complete automated deployment script for Wiz Technical Exercise
# This script deploys everything from infrastructure to application

set -e

echo "=========================================="
echo "Wiz Technical Exercise - Full Deployment"
echo "=========================================="
echo ""

START_TIME=$(date +%s)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get AWS account info
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")

echo "Deployment Configuration:"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  AWS Region: $AWS_REGION"
echo ""

# Step 1: Run prerequisites check
echo -e "${BLUE}[1/6] Running prerequisites check...${NC}"
echo "-----------------------------------"
if [ -f scripts/setup-prerequisites.sh ]; then
    bash scripts/setup-prerequisites.sh
else
    echo "⚠️  Prerequisites script not found. Continuing anyway..."
fi
echo ""

# Step 2: Deploy infrastructure with Terraform
echo -e "${BLUE}[2/6] Deploying infrastructure with Terraform...${NC}"
echo "-----------------------------------------------"
cd terraform

if [ ! -f terraform.tfvars ]; then
    echo "❌ terraform.tfvars not found!"
    echo "   Run: ./scripts/setup-prerequisites.sh"
    exit 1
fi

echo "Initializing Terraform..."
terraform init -upgrade

echo ""
echo "Planning infrastructure deployment..."
terraform plan -out=tfplan

echo ""
echo "Applying infrastructure deployment..."
echo "⏱️  This will take approximately 15-20 minutes..."
terraform apply tfplan

echo ""
echo -e "${GREEN}✅ Infrastructure deployed successfully!${NC}"
echo ""

# Save outputs
terraform output > ../outputs.txt

# Extract important outputs
EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "wiz-exercise-cluster")
MONGODB_IP=$(terraform output -raw mongodb_vm_public_ip 2>/dev/null || echo "")
S3_BUCKET=$(terraform output -raw mongodb_backup_bucket 2>/dev/null || echo "")
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")

cd ..

echo "Infrastructure Details:"
echo "  EKS Cluster: $EKS_CLUSTER_NAME"
echo "  MongoDB IP: $MONGODB_IP"
echo "  S3 Bucket: $S3_BUCKET"
echo "  VPC ID: $VPC_ID"
echo ""

# Step 3: Wait for MongoDB to be ready
echo -e "${BLUE}[3/6] Waiting for MongoDB VM to be ready...${NC}"
echo "-------------------------------------------"
echo "⏱️  Waiting 2 minutes for MongoDB VM initialization..."
sleep 120

# Test SSH connectivity
echo "Testing SSH connectivity to MongoDB VM..."
MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if nc -zv -w 5 $MONGODB_IP 22 2>&1 | grep -q succeeded; then
        echo -e "${GREEN}✅ MongoDB VM is accessible via SSH${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT+1))
    echo "   Retry $RETRY_COUNT/$MAX_RETRIES..."
    sleep 10
done

# Test MongoDB port
echo "Testing MongoDB connectivity..."
if nc -zv -w 5 $MONGODB_IP 27017 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✅ MongoDB is accessible on port 27017${NC}"
else
    echo -e "${YELLOW}⚠️  MongoDB port not yet accessible. It may take a few more minutes.${NC}"
fi
echo ""

# Step 4: Configure kubectl for EKS
echo -e "${BLUE}[4/6] Configuring kubectl for EKS...${NC}"
echo "------------------------------------"
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME

echo "Verifying cluster connection..."
kubectl get nodes

echo -e "${GREEN}✅ kubectl configured successfully!${NC}"
echo ""

# Step 5: Update Kubernetes configurations
echo -e "${BLUE}[5/6] Updating Kubernetes configurations...${NC}"
echo "-------------------------------------------"

# Update ConfigMap with MongoDB IP
if [ -n "$MONGODB_IP" ]; then
    echo "Updating MongoDB IP in ConfigMap..."
    # Use a more robust sed command that works on both macOS and Linux
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|mongodb://[0-9.]*:27017|mongodb://${MONGODB_IP}:27017|g" k8s/configmap.yaml
    else
        sed -i "s|mongodb://[0-9.]*:27017|mongodb://${MONGODB_IP}:27017|g" k8s/configmap.yaml
    fi
    echo -e "${GREEN}✅ ConfigMap updated with MongoDB IP: $MONGODB_IP${NC}"
else
    echo -e "${YELLOW}⚠️  Could not determine MongoDB IP. Please update k8s/configmap.yaml manually.${NC}"
fi

# Update deployment with correct ECR image
echo "Updating deployment with ECR image..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|[0-9]\{12\}\.dkr\.ecr\.[a-z0-9-]*\.amazonaws\.com|${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com|g" k8s/deployment.yaml
else
    sed -i "s|[0-9]\{12\}\.dkr\.ecr\.[a-z0-9-]*\.amazonaws\.com|${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com|g" k8s/deployment.yaml
fi
echo -e "${GREEN}✅ Deployment updated with correct ECR registry${NC}"
echo ""

# Step 6: Build and deploy application
echo -e "${BLUE}[6/6] Building and deploying application...${NC}"
echo "-------------------------------------------"

# Check if ECR repository exists, create if not
echo "Checking ECR repository..."
if ! aws ecr describe-repositories --repository-names todo-app --region $AWS_REGION >/dev/null 2>&1; then
    echo "Creating ECR repository..."
    aws ecr create-repository --repository-name todo-app --region $AWS_REGION
    echo -e "${GREEN}✅ ECR repository created${NC}"
else
    echo "✅ ECR repository already exists"
fi

# Build and push Docker image
echo ""
echo "Building Docker image..."
cd app

# Get ECR login
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build image
docker build -t todo-app:latest .

# Tag image
docker tag todo-app:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/todo-app:latest

# Push image
echo "Pushing image to ECR..."
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/todo-app:latest

echo -e "${GREEN}✅ Docker image built and pushed to ECR${NC}"
cd ..

# Deploy to Kubernetes
echo ""
echo "Deploying to Kubernetes..."
./deploy.sh

echo ""
echo -e "${GREEN}✅ Application deployed to Kubernetes!${NC}"
echo ""

# Wait for LoadBalancer
echo "Waiting for LoadBalancer to provision (this may take 2-3 minutes)..."
sleep 30

LB_HOSTNAME=""
for i in {1..12}; do
    LB_HOSTNAME=$(kubectl get svc -n todo-app todo-app-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$LB_HOSTNAME" ]; then
        break
    fi
    echo "   Waiting... ($i/12)"
    sleep 15
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "=========================================="
echo "🎉 Deployment Complete!"
echo "=========================================="
echo ""
echo "⏱️  Total deployment time: ${MINUTES}m ${SECONDS}s"
echo ""
echo "📋 Deployment Summary:"
echo "-----------------------------------"
echo "Infrastructure:"
echo "  ✅ VPC ID: $VPC_ID"
echo "  ✅ EKS Cluster: $EKS_CLUSTER_NAME"
echo "  ✅ MongoDB VM: $MONGODB_IP"
echo "  ✅ S3 Backup Bucket: $S3_BUCKET"
echo ""
echo "Application:"
if [ -n "$LB_HOSTNAME" ]; then
    echo "  ✅ LoadBalancer URL: http://${LB_HOSTNAME}"
    echo ""
    echo "🌐 Access your application:"
    echo "   http://${LB_HOSTNAME}"
else
    echo "  ⚠️  LoadBalancer still provisioning. Get URL with:"
    echo "     kubectl get svc -n todo-app todo-app-loadbalancer"
fi
echo ""
echo "-----------------------------------"
echo ""
echo "📝 Verification Commands:"
echo "-----------------------------------"
echo "# Check Kubernetes resources:"
echo "kubectl get all -n todo-app"
echo ""
echo "# Check wizexercise.txt file:"
echo "kubectl exec -n todo-app deployment/todo-app -- cat /app/wizexercise.txt"
echo ""
echo "# Check MongoDB VM:"
echo "ssh ubuntu@${MONGODB_IP}"
echo ""
echo "# Check S3 backups:"
echo "aws s3 ls s3://${S3_BUCKET}/"
echo ""
echo "# View application logs:"
echo "kubectl logs -n todo-app -l app=todo-app"
echo ""
echo "-----------------------------------"
echo ""
echo "📚 Next Steps:"
echo "  1. Test the application in your browser"
echo "  2. Verify wizexercise.txt file exists in container"
echo "  3. Review security vulnerabilities: ./scripts/verify-security-issues.sh"
echo "  4. Prepare your presentation"
echo ""
echo "🧹 To cleanup:"
echo "  ./scripts/cleanup-all.sh"
echo ""
echo "=========================================="
