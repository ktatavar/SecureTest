#!/bin/bash
# Deploy Todo App using Helm Chart

set -e

cd "$(dirname "$0")/.."

echo "=========================================="
echo "Todo App - Helm Deployment"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm is not installed${NC}"
    echo "Install Helm: https://helm.sh/docs/intro/install/"
    exit 1
fi

echo -e "${GREEN}✅ Helm is installed: $(helm version --short)${NC}"
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ kubectl is not configured${NC}"
    echo "Configure kubectl:"
    echo "  aws eks update-kubeconfig --region us-east-1 --name wiz-exercise-cluster-v2"
    exit 1
fi

echo -e "${GREEN}✅ kubectl is configured${NC}"
echo ""

# Get MongoDB IP from Terraform
echo -e "${BLUE}[1/6] Getting MongoDB IP from Terraform...${NC}"
cd terraform
if [ ! -f terraform.tfstate ]; then
    echo -e "${RED}❌ Terraform state not found${NC}"
    echo "Run terraform apply first"
    exit 1
fi

MONGODB_IP=$(terraform output -raw mongodb_vm_public_ip 2>/dev/null || echo "")
if [ -z "$MONGODB_IP" ]; then
    echo -e "${YELLOW}⚠️  Could not get MongoDB IP from Terraform${NC}"
    read -p "Enter MongoDB IP manually: " MONGODB_IP
fi

echo "MongoDB IP: $MONGODB_IP"
cd ..

# Get AWS Account ID
echo ""
echo -e "${BLUE}[2/6] Getting AWS Account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${YELLOW}⚠️  Could not get AWS Account ID${NC}"
    read -p "Enter AWS Account ID manually: " AWS_ACCOUNT_ID
fi

echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Check if release already exists
echo ""
echo -e "${BLUE}[3/6] Checking existing Helm release...${NC}"
if helm list -n todo-app | grep -q "todo-app"; then
    echo -e "${YELLOW}⚠️  Helm release 'todo-app' already exists${NC}"
    read -p "Do you want to upgrade it? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        ACTION="upgrade"
    else
        echo "Cancelled."
        exit 0
    fi
else
    ACTION="install"
fi

# Lint the chart
echo ""
echo -e "${BLUE}[4/6] Linting Helm chart...${NC}"
helm lint ./helm/todo-app
echo -e "${GREEN}✅ Chart is valid${NC}"

# Deploy with Helm
echo ""
echo -e "${BLUE}[5/6] ${ACTION^}ing Todo App with Helm...${NC}"

if [ "$ACTION" = "install" ]; then
    helm install todo-app ./helm/todo-app \
        --create-namespace \
        --namespace todo-app \
        --set mongodb.uri="mongodb://${MONGODB_IP}:27017/todoapp" \
        --set image.repository="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/todo-app" \
        --set image.tag="latest" \
        --wait \
        --timeout 5m
else
    helm upgrade todo-app ./helm/todo-app \
        --namespace todo-app \
        --set mongodb.uri="mongodb://${MONGODB_IP}:27017/todoapp" \
        --set image.repository="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/todo-app" \
        --set image.tag="latest" \
        --wait \
        --timeout 5m
fi

echo -e "${GREEN}✅ Helm ${ACTION} completed${NC}"

# Wait for pods to be ready
echo ""
echo -e "${BLUE}[6/6] Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod \
    -l app=todo-app \
    -n todo-app \
    --timeout=120s

echo -e "${GREEN}✅ Pods are ready${NC}"

# Get LoadBalancer URL
echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""

echo "Helm Release Status:"
helm status todo-app -n todo-app

echo ""
echo "Getting LoadBalancer URL (may take 2-3 minutes)..."
echo ""

# Wait for LoadBalancer to be assigned
for i in {1..60}; do
    LB_URL=$(kubectl get svc -n todo-app todo-app-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$LB_URL" ]; then
        break
    fi
    echo -n "."
    sleep 5
done

echo ""
echo ""

if [ -n "$LB_URL" ]; then
    echo -e "${GREEN}✅ LoadBalancer is ready!${NC}"
    echo ""
    echo "Application URL: http://$LB_URL"
    echo ""
    echo "Test the application:"
    echo "  curl http://$LB_URL/health"
    echo ""
    echo "Open in browser:"
    echo "  open http://$LB_URL  # macOS"
    echo "  xdg-open http://$LB_URL  # Linux"
else
    echo -e "${YELLOW}⚠️  LoadBalancer URL not ready yet${NC}"
    echo "Run this command to check status:"
    echo "  kubectl get svc -n todo-app todo-app-loadbalancer -w"
fi

echo ""
echo "Useful commands:"
echo "  helm list -n todo-app"
echo "  kubectl get all -n todo-app"
echo "  kubectl logs -f -l app=todo-app -n todo-app"
echo "  kubectl exec -n todo-app deployment/todo-app -- cat /app/wizexercise.txt"
echo ""
