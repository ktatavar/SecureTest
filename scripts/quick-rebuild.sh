#!/bin/bash
# Quick rebuild script - Only recreates MongoDB VM and app

set -e

cd "$(dirname "$0")/.."

echo "=========================================="
echo "Quick Rebuild - MongoDB + App"
echo "=========================================="
echo ""

# Step 1: Taint MongoDB VM
echo "[1/4] Marking MongoDB VM for recreation..."
cd terraform
terraform workspace select default
terraform taint aws_instance.mongodb_vm

# Step 2: Apply Terraform changes
echo ""
echo "[2/4] Recreating MongoDB VM (2-3 minutes)..."
terraform apply -auto-approve

# Step 3: Get new MongoDB IP
echo ""
echo "[3/4] Getting new MongoDB IP..."
MONGODB_IP=$(terraform output -raw mongodb_vm_public_ip)
echo "MongoDB IP: $MONGODB_IP"

# Step 4: Update Kubernetes ConfigMap and redeploy
echo ""
echo "[4/4] Updating application..."
cd ..

# Update ConfigMap with new MongoDB IP
cat > /tmp/updated-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: todo-app-config
  namespace: todo-app
data:
  MONGODB_URI: "mongodb://${MONGODB_IP}:27017/todoapp"
  PORT: "3000"
EOF

# Apply updates
kubectl apply -f /tmp/updated-configmap.yaml
kubectl rollout restart deployment/todo-app -n todo-app

echo ""
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=todo-app -n todo-app --timeout=120s

echo ""
echo "=========================================="
echo "✅ Quick Rebuild Complete!"
echo "=========================================="
echo ""
echo "MongoDB IP: $MONGODB_IP"
echo "App URL: $(kubectl get svc -n todo-app todo-app-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo ""
echo "Total time: ~3-4 minutes"
