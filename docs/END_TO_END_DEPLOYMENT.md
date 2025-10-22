# End-to-End Automated Deployment

This guide explains the automated end-to-end deployment workflow that orchestrates the complete deployment process from container build to running application.

## 📋 Overview

The end-to-end workflow automates three sequential stages:

1. **Build & Push** - Build container image and push to ECR
2. **Terraform Deploy** - Provision AWS infrastructure (VPC, EKS, MongoDB)
3. **Helm Deploy** - Deploy application to Kubernetes

**Total Time**: ~20-30 minutes (fully automated)

---

## 🔧 Prerequisites

### Required Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN` | IAM role ARN for OIDC authentication |

### Required Permissions

The IAM role needs permissions for:
- ECR (push images)
- EKS (create/manage clusters)
- EC2 (create VMs, VPCs, security groups)
- S3 (Terraform state, MongoDB backups)
- IAM (create roles for EKS)

---

## 🚀 How to Enable

### Step 1: Edit Workflow File

Edit `.github/workflows/deploy-end-to-end.yml`:

```yaml
# Change this:
# on:
#   workflow_dispatch:

# To this:
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - staging
          - prod
```

### Step 2: Remove Disabled Flags

```yaml
# In each job, change:
if: false  # DISABLED

# To:
# (remove the line entirely)
```

### Step 3: Commit and Push

```bash
git add .github/workflows/deploy-end-to-end.yml
git commit -m "Enable end-to-end deployment workflow"
git push origin main
```

---

## 📖 Usage

### Trigger Deployment

**Via GitHub UI:**
1. Go to **Actions** tab
2. Select **End-to-End Deployment**
3. Click **Run workflow**
4. Select environment (dev/staging/prod)
5. Choose whether to destroy existing infrastructure
6. Click **Run workflow**

**Via GitHub CLI:**
```bash
gh workflow run deploy-end-to-end.yml \
  -f environment=dev \
  -f destroy_existing=false
```

---

## 🔄 Deployment Flow

### Stage 1: Build and Push (5-10 minutes)

```
┌─────────────────────────────────────┐
│  Build Container Image              │
│  - Checkout code                    │
│  - Build with Docker Buildx         │
│  - Tag: latest, dev, sha-xxx        │
│  - Push to ECR                      │
│  - Run Trivy security scan          │
└─────────────────────────────────────┘
           │
           ▼
    ✅ Image Ready
```

**Outputs:**
- `image_tag`: Full image tag
- `image_digest`: Image digest

### Stage 2: Terraform Deploy (15-20 minutes)

```
┌─────────────────────────────────────┐
│  Provision Infrastructure           │
│  1. Initialize Terraform            │
│  2. Check existing infrastructure   │
│  3. Destroy if requested (optional) │
│  4. Plan infrastructure             │
│  5. Apply Terraform                 │
│  6. Wait for stabilization          │
│     - VPC: 2-3 min                  │
│     - NAT Gateway: 2-3 min          │
│     - EKS Cluster: 10-15 min        │
│     - EKS Nodes: 3-5 min            │
│     - MongoDB VM: 2-3 min           │
│  7. Verify MongoDB ready            │
└─────────────────────────────────────┘
           │
           ▼
    ✅ Infrastructure Ready
```

**Outputs:**
- `mongodb_ip`: MongoDB VM IP address
- `eks_cluster_name`: EKS cluster name
- `vpc_id`: VPC ID

**Wait Times:**
- EKS cluster status check: Up to 15 minutes
- Additional node stabilization: 2 minutes
- MongoDB readiness: Up to 5 minutes

### Stage 3: Helm Deploy (5-10 minutes)

```
┌─────────────────────────────────────┐
│  Deploy Application                 │
│  1. Configure kubectl               │
│  2. Wait for EKS nodes ready        │
│  3. Lint Helm chart                 │
│  4. Install/Upgrade with Helm       │
│  5. Wait for pods ready             │
│  6. Wait for LoadBalancer           │
│     - Provisioning: 2-3 min         │
│  7. Test application health         │
│  8. Verify wizexercise.txt          │
└─────────────────────────────────────┘
           │
           ▼
    ✅ Application Running
```

**Wait Times:**
- EKS nodes ready: Up to 5 minutes
- Helm deployment: Up to 10 minutes
- LoadBalancer provisioning: 2-3 minutes
- Application health check: Up to 2 minutes

---

## ⏱️ Timing Breakdown

| Stage | Minimum | Typical | Maximum |
|-------|---------|---------|---------|
| **Build & Push** | 3 min | 5 min | 10 min |
| **Terraform Deploy** | 12 min | 18 min | 25 min |
| **Helm Deploy** | 5 min | 7 min | 15 min |
| **Total** | **20 min** | **30 min** | **50 min** |

---

## 🎯 Features

### Intelligent Wait Times

The workflow includes smart waiting mechanisms:

**EKS Cluster:**
- Polls every 30 seconds
- Maximum 30 attempts (15 minutes)
- Checks for ACTIVE status

**EKS Nodes:**
- Polls every 15 seconds
- Maximum 20 attempts (5 minutes)
- Checks for Ready status

**MongoDB:**
- Tests port 27017 connectivity
- Polls every 15 seconds
- Maximum 20 attempts (5 minutes)

**LoadBalancer:**
- Polls every 10 seconds
- Maximum 40 attempts (6-7 minutes)
- Checks for hostname assignment

### Dependency Management

Jobs run in sequence with proper dependencies:

```
build-and-push
      ↓
terraform-deploy (needs: build-and-push)
      ↓
helm-deploy (needs: terraform-deploy)
      ↓
deployment-summary (needs: all)
```

### Error Handling

- Each stage can fail independently
- Terraform checks for existing infrastructure
- Helm checks for existing releases
- Comprehensive status reporting

---

## 📊 Monitoring Deployment

### View Progress

**GitHub Actions UI:**
- Real-time logs for each job
- Progress indicators
- Timing information

**Watch Specific Resources:**

```bash
# Watch EKS cluster
aws eks describe-cluster --name wiz-exercise-cluster-v2 --region us-east-1

# Watch EKS nodes
kubectl get nodes -w

# Watch pods
kubectl get pods -n todo-app -w

# Watch LoadBalancer
kubectl get svc -n todo-app todo-app-loadbalancer -w
```

### Deployment Summary

After completion, check the **Summary** tab for:
- Container image details
- Infrastructure resources created
- Application deployment status
- LoadBalancer URL
- Verification commands

---

## 🔧 Configuration

### Environment Variables

Customize in the workflow file:

```yaml
env:
  AWS_REGION: us-east-1              # AWS region
  IMAGE_NAME: todo-app               # Container image name
  EKS_CLUSTER_NAME: wiz-exercise-cluster-v2  # EKS cluster name
  TERRAFORM_VERSION: 1.9.0           # Terraform version
  HELM_VERSION: v3.13.0              # Helm version
  KUBECTL_VERSION: v1.28.0           # kubectl version
```

### Workflow Inputs

```yaml
environment:
  - dev      # Development environment
  - staging  # Staging environment
  - prod     # Production environment

destroy_existing:
  - false    # Keep existing infrastructure
  - true     # Destroy and recreate
```

---

## 🧹 Cleanup

### Via Workflow (Future Enhancement)

Create a cleanup workflow or add cleanup job:

```bash
# Helm cleanup
helm uninstall todo-app -n todo-app

# Terraform cleanup
cd terraform && terraform destroy -auto-approve
```

### Manual Cleanup

```bash
# Use cleanup scripts
./scripts/cleanup-helm.sh --force
cd terraform && terraform destroy -auto-approve
```

---

## 🔍 Troubleshooting

### Issue: EKS Cluster Timeout

**Symptom:** Workflow times out waiting for EKS cluster

**Solution:**
- Check AWS service limits
- Verify IAM permissions
- Check CloudWatch logs for EKS

### Issue: MongoDB Not Ready

**Symptom:** MongoDB connectivity test fails

**Solution:**
- Check security group rules
- Verify cloud-init logs: `ssh ubuntu@<ip> 'sudo tail -f /var/log/cloud-init-output.log'`
- Increase wait time in workflow

### Issue: LoadBalancer Stuck

**Symptom:** LoadBalancer never gets hostname

**Solution:**
- Check subnet tags for EKS
- Verify IAM role for EKS service
- Check AWS ELB service limits

### Issue: Pods Not Starting

**Symptom:** Pods remain in Pending state

**Solution:**
- Check node capacity: `kubectl describe nodes`
- Check pod events: `kubectl describe pod -n todo-app <pod-name>`
- Verify image pull: `kubectl get events -n todo-app`

---

## 📈 Optimization Tips

### Reduce Deployment Time

1. **Use Existing Infrastructure:**
   - Set `destroy_existing: false`
   - Saves 15-20 minutes

2. **Parallel Builds:**
   - Build image while Terraform runs (future enhancement)

3. **Smaller EKS Nodes:**
   - Use t3.small instead of t3.medium
   - Faster provisioning

4. **Reduce Wait Times:**
   - Adjust polling intervals
   - Reduce maximum attempts

### Cost Optimization

1. **Destroy After Testing:**
   - Set `destroy_existing: true` for next run
   - Or use cleanup scripts

2. **Use Spot Instances:**
   - Configure in Terraform
   - Significant cost savings

3. **Scale Down:**
   - Reduce replica count
   - Use smaller instance types

---

## 🎯 Best Practices

### Development Workflow

```bash
# 1. Make changes locally
git checkout -b feature/my-change
# ... make changes ...
git commit -am "My changes"
git push origin feature/my-change

# 2. Create PR to main
gh pr create

# 3. After PR merge, trigger deployment
gh workflow run deploy-end-to-end.yml -f environment=dev
```

### Production Deployment

```bash
# 1. Deploy to dev first
gh workflow run deploy-end-to-end.yml -f environment=dev

# 2. Test thoroughly
curl http://<loadbalancer-url>/health

# 3. Deploy to staging
gh workflow run deploy-end-to-end.yml -f environment=staging

# 4. Final testing

# 5. Deploy to production
gh workflow run deploy-end-to-end.yml -f environment=prod
```

### Monitoring

- Enable CloudWatch logs for EKS
- Set up alerts for deployment failures
- Monitor application metrics
- Track deployment duration

---

## 📚 Related Documentation

- [Helm Deployment Guide](HELM_DEPLOYMENT.md)
- [Helm GitHub Actions](HELM_GITHUB_ACTIONS.md)
- [Deploy to New Account](DEPLOY_NEW_ACCOUNT.md)
- [Complete Guide](../COMPLETE_GUIDE.md)

---

## ✅ Summary

**End-to-End Workflow:**
- ✅ Fully automated deployment
- ✅ Proper sequencing with dependencies
- ✅ Intelligent wait times for infrastructure
- ✅ Comprehensive error handling
- ✅ Detailed status reporting
- ✅ 20-30 minute total deployment time

**To Enable:**
1. Uncomment `on:` triggers
2. Remove `if: false` from jobs
3. Set up AWS OIDC and secrets
4. Commit and push

**Currently DISABLED for safety!**

---

*Last Updated: October 22, 2025*
