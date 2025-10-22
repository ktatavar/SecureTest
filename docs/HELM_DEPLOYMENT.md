# Helm Chart Deployment Guide

This guide explains how to deploy the Todo App using the Helm chart instead of raw Kubernetes manifests.

## 📋 Prerequisites

### Required Tools
```bash
# Check Helm installation
helm version
# Required: Helm 3.0+

# Check kubectl
kubectl version --client

# Check cluster access
kubectl cluster-info
```

### Install Helm (if needed)
```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Windows
choco install kubernetes-helm
```

---

## 🚀 Quick Deployment

### Option 1: Automated Script (Easiest)

```bash
# Run the automated Helm deployment script
./scripts/deploy-helm.sh
```

**What it does:**
- ✅ Validates Helm and kubectl are installed
- ✅ Gets MongoDB IP from Terraform automatically
- ✅ Gets AWS Account ID automatically
- ✅ Lints the Helm chart
- ✅ Installs or upgrades the release
- ✅ Waits for pods to be ready
- ✅ Shows LoadBalancer URL

**Time:** 3-5 minutes

### Option 2: Manual Helm Install

```bash
# Get MongoDB IP
cd terraform
MONGODB_IP=$(terraform output -raw mongodb_vm_public_ip)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Install with Helm
helm install todo-app ./helm/todo-app \
  --create-namespace \
  --namespace todo-app \
  --set mongodb.uri="mongodb://${MONGODB_IP}:27017/todoapp" \
  --set image.repository="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/todo-app" \
  --wait

# Get LoadBalancer URL
kubectl get svc -n todo-app todo-app-loadbalancer
```

---

## 📊 Helm Chart Structure

```
helm/todo-app/
├── Chart.yaml                    # Chart metadata
├── values.yaml                   # Default configuration values
├── .helmignore                   # Files to ignore
├── README.md                     # Chart documentation
├── templates/
│   ├── _helpers.tpl             # Template helpers
│   ├── NOTES.txt                # Post-install notes
│   ├── namespace.yaml           # Namespace resource
│   ├── serviceaccount.yaml      # ServiceAccount
│   ├── clusterrolebinding.yaml  # ClusterRoleBinding (INSECURE)
│   ├── configmap.yaml           # ConfigMap for env vars
│   ├── secret.yaml              # Secret for MongoDB creds
│   ├── deployment.yaml          # Deployment spec
│   ├── service.yaml             # ClusterIP service
│   ├── loadbalancer.yaml        # LoadBalancer service
│   └── networkpolicy.yaml       # NetworkPolicy
└── charts/                       # Dependency charts (empty)
```

---

## ⚙️ Configuration

### Key Values

The chart can be configured via `values.yaml` or `--set` flags:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace.name` | Namespace name | `todo-app` |
| `replicaCount` | Number of pod replicas | `3` |
| `image.repository` | Container image repo | ECR URL |
| `image.tag` | Container image tag | `latest` |
| `mongodb.uri` | MongoDB connection string | MongoDB IP |
| `serviceAccount.clusterAdmin` | Grant cluster-admin (INSECURE) | `true` |
| `loadBalancer.enabled` | Enable LoadBalancer | `true` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `resources.limits.memory` | Memory limit | `256Mi` |

### Custom Values File

Create a custom values file:

```bash
cat > custom-values.yaml << EOF
replicaCount: 5

mongodb:
  uri: "mongodb://YOUR_IP:27017/todoapp"

image:
  repository: YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/todo-app
  tag: v2.0.0

resources:
  limits:
    memory: "512Mi"
    cpu: "1000m"

loadBalancer:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
EOF

# Install with custom values
helm install todo-app ./helm/todo-app -f custom-values.yaml
```

---

## 🔄 Helm Operations

### Install

```bash
# Basic install
helm install todo-app ./helm/todo-app

# Install with custom values
helm install todo-app ./helm/todo-app \
  --set replicaCount=5 \
  --set image.tag=v2.0.0

# Install with values file
helm install todo-app ./helm/todo-app -f custom-values.yaml

# Dry run (test without installing)
helm install todo-app ./helm/todo-app --dry-run --debug
```

### Upgrade

```bash
# Upgrade with new values
helm upgrade todo-app ./helm/todo-app \
  --set image.tag=v2.0.0

# Upgrade with values file
helm upgrade todo-app ./helm/todo-app -f custom-values.yaml

# Upgrade and wait for completion
helm upgrade todo-app ./helm/todo-app --wait --timeout 5m
```

### Rollback

```bash
# View release history
helm history todo-app -n todo-app

# Rollback to previous version
helm rollback todo-app -n todo-app

# Rollback to specific revision
helm rollback todo-app 2 -n todo-app
```

### Status & Info

```bash
# Check release status
helm status todo-app -n todo-app

# List all releases
helm list -n todo-app

# Get all values (including defaults)
helm get values todo-app -n todo-app --all

# Get manifest
helm get manifest todo-app -n todo-app

# Get release notes
helm get notes todo-app -n todo-app
```

### Uninstall

```bash
# Uninstall release
helm uninstall todo-app -n todo-app

# Uninstall and delete namespace
helm uninstall todo-app -n todo-app
kubectl delete namespace todo-app
```

---

## 🎨 Customization Examples

### Example 1: Scale Replicas

```bash
helm upgrade todo-app ./helm/todo-app \
  --set replicaCount=10 \
  --namespace todo-app
```

### Example 2: Use Network Load Balancer (AWS)

```bash
helm upgrade todo-app ./helm/todo-app \
  --set 'loadBalancer.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-type=nlb' \
  --namespace todo-app
```

### Example 3: Increase Resources

```bash
helm upgrade todo-app ./helm/todo-app \
  --set resources.limits.memory=1Gi \
  --set resources.limits.cpu=2000m \
  --namespace todo-app
```

### Example 4: Disable Network Policy

```bash
helm upgrade todo-app ./helm/todo-app \
  --set networkPolicy.enabled=false \
  --namespace todo-app
```

### Example 5: Change Image Tag

```bash
helm upgrade todo-app ./helm/todo-app \
  --set image.tag=v2.0.0 \
  --namespace todo-app
```

---

## 🔍 Verification

### Verify Installation

```bash
# Check Helm release
helm status todo-app -n todo-app

# Check all resources
kubectl get all -n todo-app

# Check pods
kubectl get pods -n todo-app

# Check services
kubectl get svc -n todo-app

# Check LoadBalancer URL
kubectl get svc todo-app-loadbalancer -n todo-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Verify Application

```bash
# Get LoadBalancer URL
LB_URL=$(kubectl get svc -n todo-app todo-app-loadbalancer \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl http://$LB_URL/health

# Create a todo
curl -X POST http://$LB_URL/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Test from Helm deployment"}'

# List todos
curl http://$LB_URL/api/todos | jq .
```

### Verify Security Vulnerabilities

```bash
# Check cluster-admin role
kubectl get clusterrolebinding todo-app-admin-binding -o yaml

# Verify wizexercise.txt
kubectl exec -n todo-app deployment/todo-app -- cat /app/wizexercise.txt

# Check service account
kubectl get sa todo-app-admin -n todo-app -o yaml
```

---

## 🛠️ Development & Testing

### Lint Chart

```bash
# Lint the chart
helm lint ./helm/todo-app

# Lint with custom values
helm lint ./helm/todo-app -f custom-values.yaml
```

### Template Rendering

```bash
# Render templates locally
helm template todo-app ./helm/todo-app

# Render with custom values
helm template todo-app ./helm/todo-app \
  --set mongodb.uri="mongodb://10.0.0.1:27017/todoapp"

# Debug template rendering
helm template todo-app ./helm/todo-app --debug

# Show only specific template
helm template todo-app ./helm/todo-app -s templates/deployment.yaml
```

### Package Chart

```bash
# Package the chart
helm package ./helm/todo-app

# This creates: todo-app-1.0.0.tgz

# Install from package
helm install todo-app todo-app-1.0.0.tgz
```

---

## 🔧 Troubleshooting

### Issue: Helm Not Found

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

### Issue: Release Already Exists

```bash
# Check existing releases
helm list -n todo-app

# Upgrade instead of install
helm upgrade todo-app ./helm/todo-app

# Or uninstall first
helm uninstall todo-app -n todo-app
helm install todo-app ./helm/todo-app
```

### Issue: Pods Not Starting

```bash
# Check pod status
kubectl get pods -n todo-app

# Describe pod
kubectl describe pod -n todo-app <pod-name>

# Check logs
kubectl logs -n todo-app <pod-name>

# Check Helm release status
helm status todo-app -n todo-app
```

### Issue: LoadBalancer Pending

```bash
# Check service events
kubectl describe svc todo-app-loadbalancer -n todo-app

# Wait for LoadBalancer
kubectl get svc -n todo-app todo-app-loadbalancer -w

# Check AWS ELB (if on AWS)
aws elbv2 describe-load-balancers --region us-east-1
```

### Issue: Template Rendering Error

```bash
# Debug template rendering
helm template todo-app ./helm/todo-app --debug

# Validate values
helm lint ./helm/todo-app -f custom-values.yaml

# Check specific template
helm template todo-app ./helm/todo-app -s templates/deployment.yaml
```

---

## 📊 Comparison: Helm vs Raw Manifests

| Aspect | Raw Manifests | Helm Chart |
|--------|---------------|------------|
| **Deployment** | `kubectl apply -f k8s/` | `helm install todo-app ./helm/todo-app` |
| **Configuration** | Edit YAML files | `--set` flags or values file |
| **Upgrades** | Manual `kubectl apply` | `helm upgrade` with rollback |
| **Versioning** | Git commits | Helm revisions |
| **Rollback** | Manual revert | `helm rollback` |
| **Templating** | None | Full Go templating |
| **Reusability** | Copy/paste | Parameterized chart |
| **Package** | Directory of files | Single `.tgz` file |

---

## 🎯 Best Practices

### 1. Use Values Files for Environments

```bash
# values-dev.yaml
replicaCount: 1
resources:
  limits:
    memory: "256Mi"

# values-prod.yaml
replicaCount: 5
resources:
  limits:
    memory: "1Gi"

# Deploy to dev
helm install todo-app ./helm/todo-app -f values-dev.yaml

# Deploy to prod
helm install todo-app ./helm/todo-app -f values-prod.yaml
```

### 2. Version Your Releases

```bash
# Tag releases
helm upgrade todo-app ./helm/todo-app \
  --set image.tag=v1.2.3

# View history
helm history todo-app -n todo-app
```

### 3. Use Dry Run Before Deploy

```bash
# Test without deploying
helm install todo-app ./helm/todo-app --dry-run --debug

# Validate templates
helm template todo-app ./helm/todo-app | kubectl apply --dry-run=client -f -
```

### 4. Monitor Helm Releases

```bash
# Watch release status
watch helm list -n todo-app

# Monitor pods
watch kubectl get pods -n todo-app
```

---

## 📚 Additional Resources

- **Helm Documentation**: https://helm.sh/docs/
- **Chart Best Practices**: https://helm.sh/docs/chart_best_practices/
- **Chart Template Guide**: https://helm.sh/docs/chart_template_guide/
- **Helm Commands**: https://helm.sh/docs/helm/

---

## ✅ Summary

**Helm Deployment Advantages:**
- ✅ Single command deployment
- ✅ Easy configuration management
- ✅ Built-in rollback capability
- ✅ Version control for releases
- ✅ Templating for reusability
- ✅ Package distribution

**Quick Commands:**
```bash
# Install
./scripts/deploy-helm.sh

# Upgrade
helm upgrade todo-app ./helm/todo-app --set image.tag=v2.0.0

# Rollback
helm rollback todo-app -n todo-app

# Uninstall
helm uninstall todo-app -n todo-app
```

---

*Last Updated: October 22, 2025*
