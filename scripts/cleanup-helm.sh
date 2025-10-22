#!/bin/bash
# Cleanup Helm deployment of Todo App

set -e

cd "$(dirname "$0")/.."

echo "=========================================="
echo "Todo App - Helm Cleanup"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments
FORCE=false
KEEP_NAMESPACE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        --keep-namespace)
            KEEP_NAMESPACE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force, -f          Skip confirmation prompts"
            echo "  --keep-namespace     Keep the namespace after uninstalling"
            echo "  --help, -h           Show this help message"
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
    exit 1
fi

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ kubectl is not configured${NC}"
    exit 1
fi

# Check if release exists
echo -e "${BLUE}[1/5] Checking for Helm release...${NC}"
if ! helm list -n todo-app 2>/dev/null | grep -q "todo-app"; then
    echo -e "${YELLOW}⚠️  Helm release 'todo-app' not found${NC}"
    echo ""
    echo "Available releases:"
    helm list -A
    echo ""
    read -p "Continue with namespace cleanup? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    RELEASE_EXISTS=false
else
    echo -e "${GREEN}✅ Found Helm release 'todo-app'${NC}"
    RELEASE_EXISTS=true
fi

# Show current state
if [ "$RELEASE_EXISTS" = true ]; then
    echo ""
    echo "Current Helm Release:"
    helm status todo-app -n todo-app 2>/dev/null || true
    echo ""
fi

echo "Current Resources:"
kubectl get all -n todo-app 2>/dev/null || echo "  No resources found"
echo ""

# Confirmation prompt
if [ "$FORCE" = false ]; then
    echo -e "${YELLOW}⚠️  WARNING: This will delete:${NC}"
    if [ "$RELEASE_EXISTS" = true ]; then
        echo "  - Helm release 'todo-app'"
    fi
    echo "  - All pods, services, and deployments"
    echo "  - LoadBalancer (will be deleted from AWS)"
    echo "  - ConfigMaps and Secrets"
    echo "  - ServiceAccount and ClusterRoleBinding"
    if [ "$KEEP_NAMESPACE" = false ]; then
        echo "  - Namespace 'todo-app'"
    fi
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Uninstall Helm release
if [ "$RELEASE_EXISTS" = true ]; then
    echo ""
    echo -e "${BLUE}[2/5] Uninstalling Helm release...${NC}"
    
    helm uninstall todo-app -n todo-app
    
    echo -e "${GREEN}✅ Helm release uninstalled${NC}"
else
    echo ""
    echo -e "${BLUE}[2/5] Skipping Helm uninstall (release not found)${NC}"
fi

# Wait for LoadBalancer to be deleted
echo ""
echo -e "${BLUE}[3/5] Waiting for LoadBalancer to be deleted...${NC}"
echo "This may take 2-3 minutes..."

# Check if LoadBalancer exists
if kubectl get svc -n todo-app todo-app-loadbalancer &>/dev/null; then
    for i in {1..60}; do
        if ! kubectl get svc -n todo-app todo-app-loadbalancer &>/dev/null; then
            echo -e "${GREEN}✅ LoadBalancer deleted${NC}"
            break
        fi
        echo -n "."
        sleep 3
    done
    echo ""
else
    echo "LoadBalancer already deleted or not found"
fi

# Clean up any remaining resources
echo ""
echo -e "${BLUE}[4/5] Cleaning up remaining resources...${NC}"

# Delete any remaining resources in namespace
if kubectl get namespace todo-app &>/dev/null; then
    # Delete all resources
    kubectl delete all --all -n todo-app --timeout=60s 2>/dev/null || true
    
    # Delete ConfigMaps
    kubectl delete configmap --all -n todo-app --timeout=30s 2>/dev/null || true
    
    # Delete Secrets
    kubectl delete secret --all -n todo-app --timeout=30s 2>/dev/null || true
    
    # Delete ServiceAccounts
    kubectl delete serviceaccount --all -n todo-app --timeout=30s 2>/dev/null || true
    
    # Delete NetworkPolicies
    kubectl delete networkpolicy --all -n todo-app --timeout=30s 2>/dev/null || true
    
    echo -e "${GREEN}✅ Remaining resources cleaned up${NC}"
else
    echo "Namespace 'todo-app' not found"
fi

# Delete ClusterRoleBinding (cluster-wide resource)
echo ""
echo "Deleting ClusterRoleBinding..."
kubectl delete clusterrolebinding todo-app-admin-binding --timeout=30s 2>/dev/null || echo "  ClusterRoleBinding not found"

# Delete namespace
if [ "$KEEP_NAMESPACE" = false ]; then
    echo ""
    echo -e "${BLUE}[5/5] Deleting namespace...${NC}"
    
    if kubectl get namespace todo-app &>/dev/null; then
        kubectl delete namespace todo-app --timeout=60s
        echo -e "${GREEN}✅ Namespace deleted${NC}"
    else
        echo "Namespace 'todo-app' not found"
    fi
else
    echo ""
    echo -e "${BLUE}[5/5] Keeping namespace (--keep-namespace flag)${NC}"
fi

# Final verification
echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""

# Check if anything remains
echo "Verification:"
echo ""

# Check Helm releases
echo "Helm releases in todo-app namespace:"
if helm list -n todo-app 2>/dev/null | grep -q "todo-app"; then
    echo -e "${YELLOW}⚠️  Helm release still exists${NC}"
    helm list -n todo-app
else
    echo -e "${GREEN}✅ No Helm releases found${NC}"
fi

echo ""

# Check namespace
if [ "$KEEP_NAMESPACE" = false ]; then
    echo "Namespace status:"
    if kubectl get namespace todo-app &>/dev/null; then
        echo -e "${YELLOW}⚠️  Namespace still exists (may be terminating)${NC}"
        kubectl get namespace todo-app
    else
        echo -e "${GREEN}✅ Namespace deleted${NC}"
    fi
    echo ""
fi

# Check ClusterRoleBinding
echo "ClusterRoleBinding status:"
if kubectl get clusterrolebinding todo-app-admin-binding &>/dev/null; then
    echo -e "${YELLOW}⚠️  ClusterRoleBinding still exists${NC}"
else
    echo -e "${GREEN}✅ ClusterRoleBinding deleted${NC}"
fi

echo ""

# Check AWS LoadBalancers
echo "Checking AWS LoadBalancers..."
LB_COUNT=$(aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?contains(LoadBalancerName, 'todo-app')].LoadBalancerName" --output text 2>/dev/null | wc -w || echo "0")
if [ "$LB_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  $LB_COUNT LoadBalancer(s) still exist in AWS${NC}"
    echo "They may take a few more minutes to be fully deleted"
else
    echo -e "${GREEN}✅ No todo-app LoadBalancers found in AWS${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Helm cleanup completed successfully!${NC}"
echo "=========================================="
echo ""

# Show helpful commands
echo "Useful commands:"
echo "  helm list -A                    # List all Helm releases"
echo "  kubectl get all -A              # List all resources"
echo "  kubectl get namespace           # List namespaces"
echo ""

# If namespace was kept
if [ "$KEEP_NAMESPACE" = true ]; then
    echo -e "${BLUE}Note: Namespace 'todo-app' was kept as requested${NC}"
    echo "To delete it later:"
    echo "  kubectl delete namespace todo-app"
    echo ""
fi
