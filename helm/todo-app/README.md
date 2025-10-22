# Todo App Helm Chart

A Helm chart for deploying the Wiz Technical Exercise Todo Application with intentional security vulnerabilities.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- kubectl configured to access your cluster
- MongoDB VM deployed and accessible

## Installation

### Quick Install

```bash
# Install with default values
helm install todo-app ./helm/todo-app

# Install in specific namespace
helm install todo-app ./helm/todo-app --create-namespace --namespace todo-app
```

### Install with Custom Values

```bash
# Get MongoDB IP from Terraform
cd terraform
MONGODB_IP=$(terraform output -raw mongodb_vm_public_ip)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Install with custom MongoDB URI and image
helm install todo-app ./helm/todo-app \
  --set mongodb.uri="mongodb://${MONGODB_IP}:27017/todoapp" \
  --set image.repository="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/todo-app" \
  --create-namespace \
  --namespace todo-app
```

### Install with Custom Values File

```bash
# Create custom values file
cat > custom-values.yaml << EOF
mongodb:
  uri: "mongodb://YOUR_MONGODB_IP:27017/todoapp"

image:
  repository: YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/todo-app
  tag: latest

replicaCount: 3
EOF

# Install with custom values
helm install todo-app ./helm/todo-app -f custom-values.yaml
```

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace.create` | Create namespace | `true` |
| `namespace.name` | Namespace name | `todo-app` |
| `replicaCount` | Number of replicas | `3` |
| `image.repository` | Container image repository | `512231857943.dkr.ecr.us-east-1.amazonaws.com/todo-app` |
| `image.tag` | Container image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `mongodb.uri` | MongoDB connection URI | `mongodb://18.212.74.58:27017/todoapp` |
| `mongodb.username` | MongoDB username | `todouser` |
| `mongodb.password` | MongoDB password | `changeme123` |
| `serviceAccount.clusterAdmin` | Grant cluster-admin (INSECURE) | `true` |
| `loadBalancer.enabled` | Enable LoadBalancer service | `true` |
| `networkPolicy.enabled` | Enable NetworkPolicy | `true` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.limits.memory` | Memory limit | `256Mi` |
| `resources.limits.cpu` | CPU limit | `500m` |

### Full Configuration

See [values.yaml](values.yaml) for all available configuration options.

## Usage

### Get Application URL

```bash
# Wait for LoadBalancer to be ready
kubectl get svc -n todo-app todo-app-loadbalancer -w

# Get the URL
export LB_URL=$(kubectl get svc -n todo-app todo-app-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://$LB_URL"

# Test the application
curl http://$LB_URL/health
```

### View Deployment Status

```bash
# View all resources
kubectl get all -n todo-app

# View pods
kubectl get pods -n todo-app

# View logs
kubectl logs -f -l app=todo-app -n todo-app

# Verify wizexercise.txt file
kubectl exec -n todo-app deployment/todo-app -- cat /app/wizexercise.txt
```

### Upgrade

```bash
# Upgrade with new values
helm upgrade todo-app ./helm/todo-app \
  --set image.tag=v2.0.0 \
  --namespace todo-app

# Upgrade with new values file
helm upgrade todo-app ./helm/todo-app -f custom-values.yaml
```

### Rollback

```bash
# View release history
helm history todo-app -n todo-app

# Rollback to previous version
helm rollback todo-app -n todo-app

# Rollback to specific revision
helm rollback todo-app 1 -n todo-app
```

### Uninstall

```bash
# Uninstall the release
helm uninstall todo-app -n todo-app

# Delete namespace (if needed)
kubectl delete namespace todo-app
```

## Customization Examples

### Example 1: Change Replica Count

```bash
helm upgrade todo-app ./helm/todo-app \
  --set replicaCount=5 \
  --namespace todo-app
```

### Example 2: Use Network Load Balancer (AWS)

```bash
helm upgrade todo-app ./helm/todo-app \
  --set loadBalancer.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --namespace todo-app
```

### Example 3: Disable Network Policy

```bash
helm upgrade todo-app ./helm/todo-app \
  --set networkPolicy.enabled=false \
  --namespace todo-app
```

### Example 4: Custom Resource Limits

```bash
helm upgrade todo-app ./helm/todo-app \
  --set resources.limits.memory=512Mi \
  --set resources.limits.cpu=1000m \
  --namespace todo-app
```

## Verification

### Verify Installation

```bash
# Check Helm release status
helm status todo-app -n todo-app

# Get all values
helm get values todo-app -n todo-app

# Get manifest
helm get manifest todo-app -n todo-app

# Verify all resources
kubectl get all,cm,secret,sa,clusterrolebinding -n todo-app
```

### Verify Security Vulnerabilities

```bash
# Check cluster-admin role binding
kubectl get clusterrolebinding todo-app-admin-binding -o yaml

# Verify service account
kubectl get sa todo-app-admin -n todo-app -o yaml

# Check wizexercise.txt file
kubectl exec -n todo-app deployment/todo-app -- cat /app/wizexercise.txt
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n todo-app

# Describe pod
kubectl describe pod -n todo-app <pod-name>

# Check logs
kubectl logs -n todo-app <pod-name>
```

### LoadBalancer Stuck in Pending

```bash
# Check service events
kubectl describe svc todo-app-loadbalancer -n todo-app

# Verify subnet tags (AWS)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<VPC_ID>"
```

### Cannot Connect to MongoDB

```bash
# Check ConfigMap
kubectl get cm todo-app-config -n todo-app -o yaml

# Test MongoDB connectivity from pod
kubectl exec -n todo-app deployment/todo-app -- nc -zv <MONGODB_IP> 27017
```

## Security Warnings

⚠️ **This Helm chart contains INTENTIONAL security vulnerabilities for the Wiz Technical Exercise:**

1. **Cluster-Admin Privileges**: Pods have full cluster administrative access
2. **Weak Credentials**: Default passwords in use
3. **Public Exposure**: LoadBalancer exposes application to internet
4. **No TLS**: Unencrypted communication
5. **Outdated Dependencies**: Intentionally outdated MongoDB version

**DO NOT use this configuration in production environments!**

## Development

### Lint Chart

```bash
helm lint ./helm/todo-app
```

### Template Rendering

```bash
# Render templates locally
helm template todo-app ./helm/todo-app

# Render with custom values
helm template todo-app ./helm/todo-app -f custom-values.yaml

# Debug rendering
helm template todo-app ./helm/todo-app --debug
```

### Package Chart

```bash
# Package the chart
helm package ./helm/todo-app

# This creates: todo-app-1.0.0.tgz
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Kubernetes events: `kubectl get events -n todo-app`
3. Check Helm release status: `helm status todo-app -n todo-app`
4. Review application logs: `kubectl logs -f -l app=todo-app -n todo-app`

## License

This is a demonstration project for the Wiz Technical Exercise.
