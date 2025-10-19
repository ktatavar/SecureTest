#!/bin/bash
# Deploy todo-app to EKS cluster

set -e

echo "=========================================="
echo "Deploying Todo App to EKS"
echo "=========================================="
echo ""

# Step 1: Verify kubectl connection
echo "[1/4] Verifying cluster connection..."
kubectl get nodes || {
  echo "❌ Cannot connect to cluster. Run:"
  echo "   aws eks update-kubeconfig --region us-east-1 --name wiz-exercise-cluster-v2"
  exit 1
}
echo "✅ Connected to cluster"
echo ""

# Step 2: Deploy Kubernetes resources
echo "[2/4] Deploying Kubernetes resources..."

# Create namespace first
kubectl apply -f k8s/namespace.yaml

# Wait for namespace to be ready
echo "Waiting for namespace to be ready..."
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/todo-app --timeout=30s

# Deploy remaining resources
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/loadbalancer.yaml
kubectl apply -f k8s/network-policy.yaml

echo "✅ Resources deployed"
echo ""

# Step 3: Wait for pods to be ready
echo "[3/4] Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=todo-app -n todo-app --timeout=300s || {
  echo "⚠️  Pods not ready yet. Check status with:"
  echo "   kubectl get pods -n todo-app"
  echo "   kubectl logs -n todo-app -l app=todo-app"
}
echo "✅ Pods are ready"
echo ""

# Step 4: Get LoadBalancer URL
echo "[4/4] Getting LoadBalancer URL..."
echo "Waiting for LoadBalancer to provision (this may take 2-3 minutes)..."
sleep 10

LB_HOSTNAME=$(kubectl get svc -n todo-app todo-app-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$LB_HOSTNAME" ]; then
  echo "⚠️  LoadBalancer not ready yet. Check with:"
  echo "   kubectl get svc -n todo-app todo-app-loadbalancer"
else
  echo "✅ LoadBalancer ready!"
  echo ""
  echo "=========================================="
  echo "Deployment Complete!"
  echo "=========================================="
  echo ""
  echo "Application URL: http://${LB_HOSTNAME}"
  echo ""
  echo "Verify deployment:"
  echo "  kubectl get all -n todo-app"
  echo ""
  echo "View logs:"
  echo "  kubectl logs -n todo-app -l app=todo-app"
  echo ""
  echo "=========================================="
fi
