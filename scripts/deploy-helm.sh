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

# Parse arguments
CHART_SOURCE="local"  # local, git, oci, repo
CHART_VERSION="1.0.0"

while [[ $# -gt 0 ]]; then
    case $1 in
        --source)
            CHART_SOURCE="$2"
            shift 2
            ;;
        --version)
            CHART_VERSION="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --source <type>      Chart source: local, git, oci, repo (default: local)"
            echo "  --version <version>  Chart version (default: 1.0.0)"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Deploy from local path"
            echo "  $0 --source git --version 1.0.0      # Deploy from GitHub release"
            echo "  $0 --source oci --version 1.0.0      # Deploy from OCI registry"
            echo "  $0 --source repo                      # Deploy from Helm repository"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

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

# Determine chart location based on source
echo ""
echo -e "${BLUE}[4/6] Preparing chart source...${NC}"

case $CHART_SOURCE in
    local)
        CHART_PATH="./helm/todo-app"
        echo "Using local chart: $CHART_PATH"
        
        # Lint the chart
        helm lint "$CHART_PATH"
        echo -e "${GREEN}✅ Chart is valid${NC}"
        ;;
    git)
        CHART_PATH="https://github.com/ktatavar/SecureTest/releases/download/v${CHART_VERSION}/todo-app-${CHART_VERSION}.tgz"
        echo "Using GitHub release: $CHART_PATH"
        ;;
    oci)
        CHART_PATH="oci://ghcr.io/ktatavar/securetest/todo-app"
        echo "Using OCI registry: $CHART_PATH"
        ;;
    repo)
        # Add repository if not already added
        if ! helm repo list | grep -q "securetest"; then
            echo "Adding Helm repository..."
            helm repo add securetest https://ktatavar.github.io/SecureTest/
        fi
        helm repo update
        CHART_PATH="securetest/todo-app"
        echo "Using Helm repository: $CHART_PATH"
        ;;
    *)
        echo -e "${RED}❌ Invalid chart source: $CHART_SOURCE${NC}"
        exit 1
        ;;
esac

# Deploy with Helm
echo ""
echo -e "${BLUE}[5/6] ${ACTION^}ing Todo App with Helm...${NC}"

# Build common arguments
HELM_ARGS=(
    --namespace todo-app
    --set mongodb.uri="mongodb://${MONGODB_IP}:27017/todoapp"
    --set image.repository="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/todo-app"
    --set image.tag="latest"
    --wait
    --timeout 5m
)

# Add version for non-local sources
if [ "$CHART_SOURCE" != "local" ] && [ "$CHART_SOURCE" != "repo" ]; then
    HELM_ARGS+=(--version "$CHART_VERSION")
fi

if [ "$ACTION" = "install" ]; then
    helm install todo-app "$CHART_PATH" \
        --create-namespace \
        "${HELM_ARGS[@]}"
else
    helm upgrade todo-app "$CHART_PATH" \
        "${HELM_ARGS[@]}"
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
