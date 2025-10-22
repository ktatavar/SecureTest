# Wiz Technical Exercise - Complete Deployment & Management Guide

## 📚 Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Initial Setup & Deployment](#initial-setup--deployment)
3. [Fast Iteration Strategy](#fast-iteration-strategy)
4. [Cleanup & Teardown](#cleanup--teardown)
5. [Troubleshooting](#troubleshooting)
6. [Key Learnings](#key-learnings)

---

## 🏗️ Architecture Overview

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ VPC (10.0.0.0/16)                                     │  │
│  │                                                        │  │
│  │  ┌─────────────┐         ┌──────────────────────┐   │  │
│  │  │ Public      │         │ Private Subnets      │   │  │
│  │  │ Subnet      │         │                      │   │  │
│  │  │             │         │  ┌────────────────┐  │   │  │
│  │  │ ┌─────────┐ │         │  │ EKS Nodes      │  │   │  │
│  │  │ │   LB    │ │         │  │ (t3.medium)    │  │   │  │
│  │  │ └────┬────┘ │         │  │                │  │   │  │
│  │  │      │      │         │  │ ┌────────────┐ │  │   │  │
│  │  │ ┌────▼────┐ │         │  │ │ Todo App   │ │  │   │  │
│  │  │ │ MongoDB │ │         │  │ │ (3 pods)   │ │  │   │  │
│  │  │ │   VM    │ │         │  │ └────────────┘ │  │   │  │
│  │  │ └─────────┘ │         │  └────────────────┘  │   │  │
│  │  └─────────────┘         └──────────────────────┘   │  │
│  │                                                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ S3 Bucket (mongodb-backups)                          │  │
│  │ - Automated backups every 5 minutes                  │  │
│  │ - Public read access (intentionally insecure)        │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **IaC** | Terraform 5.0+ | Infrastructure provisioning |
| **Orchestration** | Amazon EKS (Kubernetes 1.28) | Container management |
| **Database** | MongoDB 4.0.28 on EC2 | Data persistence |
| **Application** | Node.js + Express | Todo API |
| **Storage** | Amazon S3 | Backup storage |
| **CI/CD** | GitHub Actions + ECR | Automated builds |
| **Networking** | VPC, NAT Gateway, LoadBalancer | Network isolation & routing |

### Intentional Security Issues

⚠️ **BY DESIGN - For Security Testing**

1. **Outdated Software**
   - Ubuntu 18.04 (EOL April 2023)
   - MongoDB 4.0.28 (outdated version)

2. **Network Exposure**
   - SSH exposed to 0.0.0.0/0
   - MongoDB port 27017 exposed publicly

3. **IAM Misconfigurations**
   - Overly permissive IAM role (can create EC2 instances)
   - No MFA requirements

4. **S3 Bucket Issues**
   - Public read access enabled
   - Public listing enabled
   - No encryption at rest

5. **Weak Credentials**
   - Default passwords in use
   - Credentials in ConfigMaps (not encrypted)

---

## 🚀 Initial Setup & Deployment

### Prerequisites

```bash
# Required tools
- AWS CLI (configured with credentials)
- Terraform >= 1.0
- kubectl
- Docker
- Git
- jq (for JSON parsing)

# Verify installations
aws --version
terraform --version
kubectl version --client
docker --version
```

### Step 1: Clone Repository

```bash
git clone https://github.com/ktatavar/SecureTest.git
cd SecureTest
```

### Step 2: Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "...",
#     "Account": "512231857943",
#     "Arn": "arn:aws:iam::512231857943:user/..."
# }
```

### Step 3: Create SSH Key Pair (One-time)

```bash
# Create SSH key for MongoDB VM access
aws ec2 create-key-pair \
  --key-name mongodb-vm-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/mongodb-vm-key.pem

# Set permissions
chmod 400 ~/.ssh/mongodb-vm-key.pem

# Verify
ls -l ~/.ssh/mongodb-vm-key.pem
```

### Step 4: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy (takes 15-20 minutes)
terraform apply -auto-approve

# Save outputs
terraform output > ../outputs.txt
```

**What Gets Created:**
- VPC with public/private subnets (5 min)
- NAT Gateway and Internet Gateway (3 min)
- EKS Cluster with 2 nodes (10-12 min)
- MongoDB EC2 instance (2-3 min)
- S3 bucket for backups (30 sec)
- IAM roles and security groups (1 min)

### Step 5: Configure kubectl

```bash
# Get the command from Terraform output
aws eks update-kubeconfig --region us-east-1 --name wiz-exercise-cluster-v2

# Verify cluster access
kubectl get nodes

# Expected output:
# NAME                         STATUS   ROLES    AGE   VERSION
# ip-10-0-2-xxx.ec2.internal   Ready    <none>   5m    v1.28.15
# ip-10-0-3-xxx.ec2.internal   Ready    <none>   5m    v1.28.15
```

### Step 6: Build and Push Docker Image

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  512231857943.dkr.ecr.us-east-1.amazonaws.com

# Build image
docker build -t todo-app .

# Tag image
docker tag todo-app:latest \
  512231857943.dkr.ecr.us-east-1.amazonaws.com/todo-app:latest

# Push to ECR
docker push 512231857943.dkr.ecr.us-east-1.amazonaws.com/todo-app:latest
```

### Step 7: Deploy Application to Kubernetes

```bash
# Get MongoDB IP from Terraform
cd terraform
MONGODB_IP=$(terraform output -raw mongodb_vm_public_ip)
echo "MongoDB IP: $MONGODB_IP"

# Update ConfigMap with MongoDB IP
cd ../k8s
cat > configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: todo-app-config
  namespace: todo-app
data:
  MONGODB_URI: "mongodb://${MONGODB_IP}:27017/todoapp"
  PORT: "3000"
EOF

# Deploy all resources
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f loadbalancer.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=todo-app -n todo-app --timeout=120s

# Get LoadBalancer URL
kubectl get svc -n todo-app todo-app-loadbalancer

# Wait 2-3 minutes for LoadBalancer to provision
```

### Step 8: Verify Deployment

```bash
# Get LoadBalancer URL
LB_URL=$(kubectl get svc -n todo-app todo-app-loadbalancer \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Application URL: http://$LB_URL"

# Test health endpoint
curl http://$LB_URL/health

# Create a todo
curl -X POST http://$LB_URL/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Test deployment"}'

# List todos
curl http://$LB_URL/api/todos | jq .
```

### Step 9: Verify MongoDB Backups

```bash
# SSH into MongoDB VM
ssh -i ~/.ssh/mongodb-vm-key.pem ubuntu@$MONGODB_IP

# Check backup script
cat /usr/local/bin/backup-mongodb.sh

# Check cron job
crontab -l

# Check backup logs
tail -f /var/log/mongodb-backup.log

# Exit SSH
exit

# Check S3 bucket
aws s3 ls s3://mongodb-backups-wiz-512231857943/
```

---

## ⚡ Fast Iteration Strategy

### Understanding Terraform State

Terraform tracks all resources in a **state file**. This allows you to:
- ✅ Update only what changed
- ✅ Selectively rebuild specific resources
- ✅ Keep expensive resources (VPC, EKS) running

### Resource Creation Times

| Resource | Creation Time | Keep Running? |
|----------|---------------|---------------|
| VPC + Subnets | ~5 min | ✅ Yes |
| NAT Gateway | ~2-3 min | ✅ Yes |
| EKS Cluster | ~10-12 min | ✅ Yes |
| EKS Nodes | ~3-5 min | ✅ Yes |
| MongoDB VM | ~2-3 min | 🔄 Rebuild as needed |
| S3 Bucket | ~30 sec | ✅ Yes |
| App Deployment | ~30 sec | 🔄 Rebuild often |

### Fast Rebuild Scenarios

#### Scenario 1: Update Application Code Only (30 seconds)

```bash
# Rebuild Docker image
docker build -t todo-app .
docker tag todo-app:latest 512231857943.dkr.ecr.us-east-1.amazonaws.com/todo-app:latest
docker push 512231857943.dkr.ecr.us-east-1.amazonaws.com/todo-app:latest

# Restart pods to pull new image
kubectl rollout restart deployment/todo-app -n todo-app

# Watch rollout
kubectl rollout status deployment/todo-app -n todo-app
```

#### Scenario 2: Rebuild MongoDB VM Only (2-3 minutes)

```bash
cd terraform

# Mark MongoDB VM for recreation
terraform taint aws_instance.mongodb_vm

# Apply changes (only recreates MongoDB)
terraform apply -auto-approve

# Get new IP
MONGODB_IP=$(terraform output -raw mongodb_vm_public_ip)

# Update Kubernetes ConfigMap
kubectl patch configmap todo-app-config -n todo-app \
  --type merge \
  -p "{\"data\":{\"MONGODB_URI\":\"mongodb://${MONGODB_IP}:27017/todoapp\"}}"

# Restart app to pick up new config
kubectl rollout restart deployment/todo-app -n todo-app
```

#### Scenario 3: Use Quick Rebuild Script (3-4 minutes)

```bash
# Rebuilds MongoDB + updates app automatically
bash scripts/quick-rebuild.sh
```

#### Scenario 4: Full Rebuild (20-30 minutes)

```bash
cd terraform

# Destroy everything
terraform destroy -auto-approve

# Recreate everything
terraform apply -auto-approve

# Redeploy application (follow Step 7 above)
```

### Using Terraform Workspaces for Multiple Environments

```bash
cd terraform

# Create test environment
terraform workspace new test

# Deploy test stack
terraform apply -auto-approve

# Switch back to production
terraform workspace select default

# List all workspaces
terraform workspace list

# Current workspace
terraform workspace show
```

**Benefits:**
- Isolated state files
- Same code, different environments
- Easy to switch between prod/test

---

## 🧹 Cleanup & Teardown

### Option 1: Standard Cleanup (20-30 minutes)

```bash
# Graceful cleanup with prompts
bash scripts/cleanup-all.sh

# Fast mode (skip graceful shutdown)
bash scripts/cleanup-all.sh --fast

# No prompts
bash scripts/cleanup-all.sh --force

# Fast + no prompts
bash scripts/cleanup-all.sh --fast --force
```

**What it does:**
1. Deletes Kubernetes namespace (waits for graceful pod shutdown)
2. Waits for LoadBalancers to be removed
3. Cleans up ECR repository (optional)
4. Runs `terraform destroy`
5. Handles network dependency issues automatically
6. Empties and deletes S3 bucket (optional)

### Option 2: Nuclear Cleanup (5-10 minutes)

**Use when:** Normal cleanup fails or you need speed

```bash
# Get VPC ID
cd terraform
VPC_ID=$(terraform output -raw vpc_id)

# Run nuclear cleanup
echo "DESTROY" | bash scripts/nuclear-cleanup.sh $VPC_ID us-east-1

# Then run Terraform destroy
terraform destroy -auto-approve
```

**What it does:**
1. Force deletes ALL LoadBalancers immediately
2. Force detaches and deletes network interfaces
3. Releases all Elastic IPs
4. Deletes NAT Gateways, security groups
5. Terminates EC2 instances
6. No waiting, no graceful shutdown

### Option 3: Keep Infrastructure, Remove App Only

```bash
# Delete just the application
kubectl delete namespace todo-app

# Or delete specific resources
kubectl delete deployment todo-app -n todo-app
kubectl delete svc todo-app-loadbalancer -n todo-app
```

### Cleanup Verification

```bash
# Check for remaining resources
aws eks list-clusters --region us-east-1
aws ec2 describe-instances --region us-east-1 \
  --filters 'Name=tag:Name,Values=mongodb-vm-outdated'
aws s3 ls | grep mongodb-backups
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=wiz-exercise-vpc"

# Clean up local files
rm -rf terraform/.terraform
rm -f terraform/terraform.tfstate*
rm -f terraform/.terraform.lock.hcl
rm -f outputs.txt
```

---

## 🔧 Troubleshooting

### Common Issues & Solutions

#### Issue 1: MongoDB Installation Failed

**Symptoms:**
- Cloud-init logs show MongoDB installation errors
- Can't connect to MongoDB from app

**Solution:**
```bash
# SSH into VM
ssh -i ~/.ssh/mongodb-vm-key.pem ubuntu@<MONGODB_IP>

# Check cloud-init logs
sudo cat /var/log/cloud-init-output.log | grep -i error

# Check MongoDB status
sudo systemctl status mongod

# If MongoDB not running, check installation
dpkg -l | grep mongodb

# Recreate VM
cd terraform
terraform taint aws_instance.mongodb_vm
terraform apply -auto-approve
```

**Root Cause:** GPG key expiration, version incompatibility

#### Issue 2: EKS Cluster DNS Resolution Fails

**Symptoms:**
```
Error: couldn't get current server API group list: 
dial tcp: lookup <cluster-endpoint>: no such host
```

**Solution:**
```bash
# Enable public endpoint access
aws eks update-cluster-config \
  --region us-east-1 \
  --name wiz-exercise-cluster-v2 \
  --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true

# Wait 2 minutes for update
sleep 120

# Test connection
kubectl get nodes
```

#### Issue 3: LoadBalancer Stuck in Pending

**Symptoms:**
```
NAME                    TYPE           EXTERNAL-IP   PORT(S)
todo-app-loadbalancer   LoadBalancer   <pending>     80:xxxxx/TCP
```

**Solution:**
```bash
# Check LoadBalancer events
kubectl describe svc todo-app-loadbalancer -n todo-app

# Check if subnets are tagged correctly
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --query 'Subnets[*].[SubnetId,Tags]'

# Ensure public subnet has tag:
# kubernetes.io/role/elb = 1

# Wait 3-5 minutes for AWS to provision
```

#### Issue 4: Terraform Destroy Fails - VPC Has Dependencies

**Symptoms:**
```
Error: deleting EC2 VPC: DependencyViolation: 
The vpc has dependencies and cannot be deleted
```

**Solution:**
```bash
# Option 1: Use cleanup script
bash scripts/cleanup-network-dependencies.sh <VPC_ID>

# Option 2: Use nuclear cleanup
echo "DESTROY" | bash scripts/nuclear-cleanup.sh <VPC_ID> us-east-1

# Option 3: Manual cleanup
# Delete LoadBalancers
aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='<VPC_ID>'].LoadBalancerArn" --output text | \
  xargs -I {} aws elbv2 delete-load-balancer --load-balancer-arn {}

# Wait 2 minutes, then retry
terraform destroy -auto-approve
```

#### Issue 5: S3 Backup Script Fails - AWS CLI Not Found

**Symptoms:**
- Backup logs show `aws: command not found`
- No backups in S3 bucket

**Solution:**
```bash
# SSH into MongoDB VM
ssh -i ~/.ssh/mongodb-vm-key.pem ubuntu@<MONGODB_IP>

# Install AWS CLI
sudo apt-get update
sudo apt-get install -y awscli

# Test backup script
sudo /usr/local/bin/backup-mongodb.sh

# Check S3
aws s3 ls s3://mongodb-backups-wiz-512231857943/
```

#### Issue 6: Pods CrashLoopBackOff

**Symptoms:**
```
NAME                        READY   STATUS             RESTARTS
todo-app-xxx-yyy            0/1     CrashLoopBackOff   5
```

**Solution:**
```bash
# Check pod logs
kubectl logs -n todo-app <pod-name>

# Common issues:
# 1. Can't connect to MongoDB
kubectl get configmap todo-app-config -n todo-app -o yaml

# 2. Image pull error
kubectl describe pod -n todo-app <pod-name>

# 3. MongoDB not ready
ssh -i ~/.ssh/mongodb-vm-key.pem ubuntu@<MONGODB_IP>
sudo systemctl status mongod
```

---

## 📊 Key Learnings

### Major Challenges Faced

#### 1. MongoDB Installation (40% of time)
- **Attempt 1:** Non-existent setup file
- **Attempt 2:** Version incompatibility (MongoDB 4.4 + Ubuntu 18.04)
- **Attempt 3:** Expired GPG keys
- **Solution:** MongoDB 4.0.28 with `--allow-unauthenticated`

#### 2. Cloud-Init Not Applying (15% of time)
- **Issue:** Changes to cloud-init didn't take effect
- **Root Cause:** Cloud-init only runs on first boot
- **Solution:** Use `terraform taint` to force VM recreation

#### 3. EKS DNS Resolution (20% of time)
- **Issue:** kubectl couldn't connect to cluster
- **Root Cause:** Private-only endpoint
- **Solution:** Enable public endpoint access

#### 4. SSH Access Issues (15% of time)
- **Issue:** Connection closed immediately
- **Root Cause:** Custom user not configured with SSH key
- **Solution:** Use default `ubuntu` user

#### 5. Terraform Workspace Conflicts (10% of time)
- **Issue:** Resource name collisions between workspaces
- **Root Cause:** Hardcoded resource names
- **Solution:** Add `${terraform.workspace}` suffix

### Best Practices Learned

✅ **Always verify cloud-init execution**
```bash
# Check logs immediately after VM creation
aws ec2 get-console-output --instance-id <ID> --latest
```

✅ **Test incrementally**
- Don't stack multiple changes without verification
- Use `terraform plan` before every apply

✅ **Use workspace-specific naming**
```hcl
resource "aws_iam_role" "mongodb_vm" {
  name = "mongodb-vm-role-${terraform.workspace}"
}
```

✅ **Account for AWS provisioning delays**
- LoadBalancers: 2-3 minutes
- NAT Gateways: 2-3 minutes
- EKS Clusters: 10-15 minutes

✅ **Keep infrastructure running for fast iteration**
- VPC + EKS = 15 minutes to create
- MongoDB VM = 2-3 minutes to recreate
- App deployment = 30 seconds

### Time Investment Breakdown

| Activity | Time Spent | Percentage |
|----------|------------|------------|
| MongoDB troubleshooting | ~4 hours | 40% |
| EKS connectivity issues | ~2 hours | 20% |
| SSH and access config | ~1.5 hours | 15% |
| Terraform workspace setup | ~1 hour | 10% |
| Application deployment | ~1 hour | 10% |
| Testing and verification | ~30 min | 5% |

**Total iterations to working stack:** 6-7 major cycles

### Architecture Decisions

#### Why Terraform over CloudFormation?
- ✅ Cloud-agnostic syntax
- ✅ Better state management
- ✅ Rich module ecosystem
- ✅ Workspace support for multi-env

#### Why EKS over Self-Managed Kubernetes?
- ✅ Managed control plane (reduced ops)
- ✅ Automatic updates and patches
- ✅ Native AWS integration
- ✅ Better security posture

#### Why Cloud-init over User Data Scripts?
- ✅ Declarative configuration
- ✅ Better error handling
- ✅ Idempotent operations
- ✅ Industry standard

#### Why Keep VPC/EKS Running?
- ✅ 15+ minutes saved per rebuild
- ✅ Cost: ~$3.50/day (acceptable for dev)
- ✅ Faster iteration = more productivity

---

## 📝 Quick Reference

### Essential Commands

```bash
# Terraform
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
terraform destroy -auto-approve
terraform taint aws_instance.mongodb_vm
terraform output
terraform workspace list
terraform workspace select <name>

# Kubernetes
kubectl get all -n todo-app
kubectl logs -n todo-app -l app=todo-app
kubectl describe pod -n todo-app <pod-name>
kubectl rollout restart deployment/todo-app -n todo-app
kubectl rollout status deployment/todo-app -n todo-app
kubectl delete namespace todo-app

# AWS
aws eks update-kubeconfig --region us-east-1 --name wiz-exercise-cluster-v2
aws s3 ls s3://mongodb-backups-wiz-512231857943/
aws ec2 describe-instances --filters "Name=tag:Name,Values=mongodb-vm-outdated"
aws eks list-clusters --region us-east-1

# Docker
docker build -t todo-app .
docker tag todo-app:latest 512231857943.dkr.ecr.us-east-1.amazonaws.com/todo-app:latest
docker push 512231857943.dkr.ecr.us-east-1.amazonaws.com/todo-app:latest

# MongoDB
ssh -i ~/.ssh/mongodb-vm-key.pem ubuntu@<MONGODB_IP>
sudo systemctl status mongod
sudo tail -f /var/log/mongodb-backup.log
```

### Important Files

```
SecureTest/
├── terraform/
│   ├── main.tf                 # Infrastructure definition
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   └── terraform.tfstate       # State file (DO NOT DELETE)
├── k8s/
│   ├── namespace.yaml          # Kubernetes namespace
│   ├── configmap.yaml          # MongoDB connection config
│   ├── secret.yaml             # Database credentials
│   ├── deployment.yaml         # App deployment
│   ├── service.yaml            # ClusterIP service
│   └── loadbalancer.yaml       # LoadBalancer service
├── mongodb-vm/
│   └── cloud-init.yaml         # VM initialization script
├── scripts/
│   ├── cleanup-all.sh          # Standard cleanup
│   ├── nuclear-cleanup.sh      # Force cleanup
│   ├── quick-rebuild.sh        # Fast MongoDB rebuild
│   └── deploy-all.sh           # Full deployment
├── Dockerfile                  # App container definition
├── deploy.sh                   # Kubernetes deployment script
└── COMPLETE_GUIDE.md          # This file
```

### Resource URLs

- **GitHub Repo:** https://github.com/ktatavar/SecureTest
- **AWS Console:** https://console.aws.amazon.com/
- **ECR Repository:** 512231857943.dkr.ecr.us-east-1.amazonaws.com/todo-app
- **S3 Bucket:** https://mongodb-backups-wiz-512231857943.s3.amazonaws.com/

---

## 🎯 Summary

This infrastructure demonstrates:
- ✅ Full infrastructure as code with Terraform
- ✅ Container orchestration with Kubernetes/EKS
- ✅ Automated CI/CD with GitHub Actions
- ✅ Automated database backups to S3
- ✅ Multi-environment support with workspaces
- ✅ Fast iteration strategy (3-4 min rebuilds)
- ✅ Intentional security vulnerabilities for testing

**Deployment Time:**
- Initial: 20-30 minutes
- Quick rebuild: 3-4 minutes
- App update only: 30 seconds

**Cost (if left running):**
- EKS: ~$0.10/hour
- EC2 (MongoDB): ~$0.04/hour
- NAT Gateway: ~$0.045/hour
- **Total: ~$3.50/day**

---

*Last Updated: October 21, 2025*
