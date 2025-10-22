# Deploy to a Different AWS Account

This guide explains how to deploy the Wiz Technical Exercise stack to a new AWS account.

## 📋 Prerequisites

### AWS Account Requirements
- ✅ Active AWS account with billing enabled
- ✅ Admin access or sufficient IAM permissions for:
  - VPC, Subnets, Internet Gateway, NAT Gateway
  - EC2 (instances, security groups, key pairs)
  - EKS (clusters, node groups)
  - S3 (buckets, policies)
  - IAM (roles, policies, instance profiles)
  - CloudWatch (logs, if enabling control plane logging)
  - Elastic Load Balancing
  - ECR (container registry)

### AWS Service Limits Required
- 1 VPC
- 4 Subnets (2 public, 2 private)
- 1 Internet Gateway
- 1 NAT Gateway
- 1 Elastic IP
- 1 EKS Cluster
- 3-5 EC2 instances (1 MongoDB VM + 2-4 EKS nodes)
- 1 S3 Bucket
- 1 Elastic Load Balancer
- 3-5 Security Groups
- 3-4 IAM Roles

### Local Tools Required
```bash
# Check if tools are installed
aws --version        # AWS CLI v2.x
terraform --version  # Terraform >= 1.0
kubectl version --client
docker --version     # Optional, for local testing
git --version
```

---

## 🚀 Quick Deployment (Automated)

### Option 1: One-Command Deployment

```bash
# 1. Clone repository
git clone https://github.com/ktatavar/SecureTest.git
cd SecureTest

# 2. Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1)

# 3. Run automated deployment
./scripts/setup-prerequisites.sh
./scripts/deploy-all.sh

# Total time: 25-40 minutes
```

---

## 📝 Manual Deployment (Step-by-Step)

### Step 1: Configure AWS Credentials

#### Option A: Use Interactive Script (Easiest) ⭐
```bash
# Run the interactive AWS account switcher
./scripts/switch-aws-account.sh

# Menu options:
# 1. Show current AWS account
# 2. List available AWS profiles
# 3. Switch to existing profile
# 4. Configure new profile
# 5. Configure default credentials
# 6. Assume IAM role
# 7. Exit
```

**This script will:**
- Guide you through credential configuration
- Automatically update `.env` file
- Verify credentials work
- Show current account details
- Handle profile switching

#### Option B: Manual Configuration

##### Method A: Default Profile (Recommended)
```bash
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region name: us-east-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

##### Method B: Named Profile
```bash
aws configure --profile wiz-demo

# Use the profile
export AWS_PROFILE=wiz-demo

# Verify
aws sts get-caller-identity
```

##### Method C: Environment Variables
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Verify
aws sts get-caller-identity
```

**Expected Output:**
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

---

### Step 2: Create SSH Key Pair

```bash
# Create key pair in AWS
aws ec2 create-key-pair \
  --key-name mongodb-vm-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/mongodb-vm-key.pem

# Set correct permissions
chmod 400 ~/.ssh/mongodb-vm-key.pem

# Verify key pair exists
aws ec2 describe-key-pairs --key-names mongodb-vm-key

# Test (should show key details)
ls -l ~/.ssh/mongodb-vm-key.pem
```

**Note:** If you want to use a different key name, update `terraform/variables.tf`:
```hcl
variable "ssh_key_name" {
  default = "your-custom-key-name"
}
```

---

### Step 3: Create ECR Repository

```bash
# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Create ECR repository for container images
aws ecr create-repository \
  --repository-name todo-app \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true

# Verify repository exists
aws ecr describe-repositories --repository-names todo-app --region us-east-1
```

---

### Step 4: Update Configuration (Optional)

The stack automatically detects your AWS account ID, but you can customize settings:

```bash
cd terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars (optional)
nano terraform.tfvars
```

**Available Variables:**
```hcl
aws_region          = "us-east-1"              # Change region if needed
cluster_name        = "wiz-exercise-cluster-v2" # Customize cluster name
ssh_key_name        = "mongodb-vm-key"          # Your SSH key name
s3_backup_bucket_name = "mongodb-backups-wiz-<account-id>" # Auto-generated
```

---

### Step 5: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform (downloads providers and modules)
terraform init

# Review what will be created (optional but recommended)
terraform plan

# Deploy infrastructure (takes 15-20 minutes)
terraform apply -auto-approve

# Save outputs for later use
terraform output > ../outputs.txt
terraform output -json > ../outputs.json

# View key outputs
terraform output mongodb_vm_public_ip
terraform output eks_cluster_endpoint
terraform output s3_bucket_name
```

**What Gets Created:**
- VPC with CIDR 10.0.0.0/16
- 2 Public subnets (10.0.1.0/24, 10.0.4.0/24)
- 2 Private subnets (10.0.2.0/24, 10.0.3.0/24)
- Internet Gateway
- NAT Gateway with Elastic IP
- MongoDB EC2 instance (t3.medium, Ubuntu 18.04)
- EKS Cluster (Kubernetes 1.28)
- EKS Node Group (2-4 t3.medium instances)
- S3 bucket for backups
- IAM roles and security groups
- Route tables and associations

**Time:** 15-20 minutes

---

### Step 6: Configure kubectl

```bash
# Configure kubectl to access the EKS cluster
aws eks update-kubeconfig \
  --region us-east-1 \
  --name wiz-exercise-cluster-v2

# Verify connection
kubectl get nodes

# Expected output:
# NAME                         STATUS   ROLES    AGE   VERSION
# ip-10-0-2-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
# ip-10-0-3-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
```

---

### Step 7: Build and Push Container Image

```bash
# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Build Docker image
docker build -t todo-app .

# Tag image for ECR
docker tag todo-app:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/todo-app:latest

# Push to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/todo-app:latest

# Verify image in ECR
aws ecr describe-images \
  --repository-name todo-app \
  --region us-east-1
```

**Time:** 5-10 minutes

---

### Step 8: Update Kubernetes Manifests

The deployment script automatically updates the MongoDB IP, but if deploying manually:

```bash
# Get MongoDB IP from Terraform
cd terraform
MONGODB_IP=$(terraform output -raw mongodb_vm_public_ip)
echo "MongoDB IP: $MONGODB_IP"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

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

# Update Deployment with correct ECR image
sed -i '' "s|512231857943|${AWS_ACCOUNT_ID}|g" deployment.yaml
```

---

### Step 9: Deploy Application to Kubernetes

#### Option A: Use Deployment Script (Recommended)
```bash
./deploy.sh
```

#### Option B: Manual Deployment
```bash
# Deploy all Kubernetes resources
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/clusterrolebinding.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/loadbalancer.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app=todo-app \
  -n todo-app \
  --timeout=120s

# Check deployment status
kubectl get all -n todo-app
```

**Time:** 5-10 minutes

---

### Step 10: Get Application URL

```bash
# Get LoadBalancer URL (may take 2-3 minutes to provision)
kubectl get svc -n todo-app todo-app-loadbalancer

# Wait for EXTERNAL-IP to be assigned
kubectl get svc -n todo-app todo-app-loadbalancer -w

# Once assigned, get the URL
LB_URL=$(kubectl get svc -n todo-app todo-app-loadbalancer \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Application URL: http://${LB_URL}"

# Test the application
curl http://${LB_URL}/health

# Open in browser
open http://${LB_URL}  # macOS
# or
xdg-open http://${LB_URL}  # Linux
```

---

### Step 11: Verify Deployment

```bash
# Run verification script
./scripts/verify-security-issues.sh

# Or manually verify:

# 1. Check wizexercise.txt file
kubectl exec -n todo-app deployment/todo-app -- cat /app/wizexercise.txt

# 2. Check cluster-admin role
kubectl get clusterrolebinding todo-app-admin-binding -o yaml

# 3. Test application
curl http://${LB_URL}/api/todos

# 4. Create a todo
curl -X POST http://${LB_URL}/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Test from new account"}'

# 5. Verify data in MongoDB
MONGODB_IP=$(cd terraform && terraform output -raw mongodb_vm_public_ip)
ssh -i ~/.ssh/mongodb-vm-key.pem ubuntu@${MONGODB_IP} \
  "mongo todoapp --eval 'db.todos.find().pretty()'"

# 6. Check S3 backups
S3_BUCKET=$(cd terraform && terraform output -raw s3_bucket_name)
aws s3 ls s3://${S3_BUCKET}/
```

---

## 💰 Cost Estimates

### Monthly Costs (us-east-1)

| Resource | Quantity | Cost/Hour | Cost/Month | Notes |
|----------|----------|-----------|------------|-------|
| EKS Control Plane | 1 | $0.10 | $73 | Fixed cost |
| EC2 t3.medium (MongoDB) | 1 | $0.042 | $31 | 24/7 |
| EC2 t3.medium (EKS nodes) | 2 | $0.084 | $62 | 24/7 |
| NAT Gateway | 1 | $0.045 | $33 | Fixed + data transfer |
| Elastic Load Balancer | 1 | $0.025 | $18 | Fixed + LCU charges |
| S3 Storage | ~1 GB | - | $0.30 | Backups |
| Data Transfer | ~10 GB | - | $1 | Outbound |
| **TOTAL** | - | **~$0.30** | **~$218** | Approximate |

**Cost Optimization Tips:**
- Stop EKS nodes when not in use: `terraform destroy -target=module.eks`
- Use Spot instances for EKS nodes (add to terraform config)
- Delete after demo: `./scripts/cleanup-all.sh`

---

## 🌍 Deploying to Different Regions

To deploy to a different AWS region:

```bash
# 1. Update region in terraform.tfvars
echo 'aws_region = "us-west-2"' >> terraform/terraform.tfvars

# 2. Create SSH key in that region
aws ec2 create-key-pair \
  --key-name mongodb-vm-key \
  --region us-west-2 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/mongodb-vm-key.pem

# 3. Create ECR repository in that region
aws ecr create-repository \
  --repository-name todo-app \
  --region us-west-2

# 4. Deploy
cd terraform
terraform init
terraform apply -auto-approve

# 5. Update kubectl config
aws eks update-kubeconfig \
  --region us-west-2 \
  --name wiz-exercise-cluster-v2
```

**Note:** Costs vary by region. Check [AWS Pricing](https://aws.amazon.com/pricing/) for your region.

---

## 🔄 AWS Account Switcher Script

### Overview

The `scripts/switch-aws-account.sh` script provides an interactive menu for managing AWS credentials and profiles. It's the **easiest way** to work with multiple AWS accounts.

### Features

| Feature | Description |
|---------|-------------|
| **Show Current Account** | Display active AWS account, user, region, and profile |
| **List Profiles** | View all configured AWS profiles |
| **Switch Profiles** | Change between existing profiles with verification |
| **Configure New Profile** | Interactive setup for new AWS accounts |
| **Configure Default** | Set up default AWS credentials |
| **Assume IAM Role** | Get temporary credentials via role assumption |
| **Auto-Update .env** | Persists profile selection across sessions |

### Usage Examples

#### Example 1: Configure New Account
```bash
./scripts/switch-aws-account.sh

# Select: 4. Configure new profile
# Enter profile name: wiz-account2
# Enter AWS Access Key ID: AKIA...
# Enter AWS Secret Access Key: ...
# Enter region: us-east-1

# Script automatically:
# - Saves credentials to ~/.aws/credentials
# - Updates .env file with AWS_PROFILE
# - Verifies credentials work
# - Shows account details
```

#### Example 2: Switch Between Accounts
```bash
./scripts/switch-aws-account.sh

# Select: 3. Switch to existing profile
# Available profiles:
#   1. default
#   2. wiz-account1
#   3. wiz-account2
# Enter profile name: wiz-account2

# Script automatically:
# - Updates .env with new profile
# - Updates AWS_ACCOUNT_ID in .env
# - Verifies new credentials
# - Shows you need to run: source .env
```

#### Example 3: Assume IAM Role
```bash
./scripts/switch-aws-account.sh

# Select: 6. Assume IAM role
# Enter Role ARN: arn:aws:iam::123456789012:role/WizExerciseRole
# Enter session name: wiz-demo-session

# Script provides temporary credentials that expire in 1 hour
# Saves to .env file
```

### Integration with Deployment

The script integrates seamlessly with the deployment process:

```bash
# 1. Configure account
./scripts/switch-aws-account.sh
# Select option 4 or 5 to configure credentials

# 2. Apply environment
source .env

# 3. Run setup (automatically uses correct account)
./scripts/setup-prerequisites.sh

# 4. Deploy
./scripts/deploy-all.sh
```

### .env File Management

The script maintains a `.env` file with:
```bash
export AWS_PROFILE=wiz-account2
export AWS_ACCOUNT_ID=123456789012
```

**Benefits:**
- Persists across terminal sessions
- Used by all deployment scripts
- Prevents accidental deployment to wrong account
- Easy to verify current configuration

### Multi-Account Workflow

```bash
# Day 1: Deploy to account 1
./scripts/switch-aws-account.sh  # Configure account1
source .env
./scripts/deploy-all.sh

# Day 2: Deploy to account 2
./scripts/switch-aws-account.sh  # Switch to account2
source .env
cd terraform && terraform workspace new account2
terraform apply -auto-approve

# Day 3: Switch back to account 1
./scripts/switch-aws-account.sh  # Switch to account1
source .env
cd terraform && terraform workspace select default
```

---

## 🔄 Multiple Accounts/Environments

### Using Terraform Workspaces

```bash
cd terraform

# Create workspace for different account
terraform workspace new account2

# Deploy to new workspace
terraform apply -auto-approve

# Switch between workspaces
terraform workspace select default  # Original account
terraform workspace select account2 # New account

# List all workspaces
terraform workspace list
```

### Using Different AWS Profiles

#### Method 1: Interactive Script (Recommended)
```bash
# Use the account switcher to manage multiple profiles
./scripts/switch-aws-account.sh

# Select option 4 to configure new profiles
# Select option 3 to switch between profiles
# The script automatically updates .env and verifies credentials
```

#### Method 2: Manual Profile Management
```bash
# Configure multiple profiles
aws configure --profile account1
aws configure --profile account2

# Deploy to account1
export AWS_PROFILE=account1
cd terraform && terraform apply -auto-approve

# Deploy to account2
export AWS_PROFILE=account2
cd terraform && terraform workspace new account2
terraform apply -auto-approve
```

**Tip:** The `switch-aws-account.sh` script maintains a `.env` file that persists your profile selection across terminal sessions.

---

## 🧹 Cleanup

### Complete Cleanup

```bash
# Option 1: Automated cleanup
./scripts/cleanup-all.sh

# Option 2: Manual cleanup
cd terraform
terraform destroy -auto-approve

# Delete ECR repository
aws ecr delete-repository \
  --repository-name todo-app \
  --region us-east-1 \
  --force

# Delete SSH key pair
aws ec2 delete-key-pair --key-name mongodb-vm-key
rm ~/.ssh/mongodb-vm-key.pem
```

### Partial Cleanup (Keep Infrastructure)

```bash
# Delete only Kubernetes resources
kubectl delete namespace todo-app

# Keep VPC, EKS, MongoDB running for fast rebuild
```

---

## 🔧 Troubleshooting

### Issue: "Insufficient permissions"

```bash
# Check your IAM permissions
aws iam get-user
aws iam list-attached-user-policies --user-name <your-username>

# Required policies:
# - AmazonEC2FullAccess
# - AmazonEKSClusterPolicy
# - AmazonS3FullAccess
# - IAMFullAccess (or specific permissions)
```

### Issue: "Key pair not found"

```bash
# List existing key pairs
aws ec2 describe-key-pairs

# Create new key pair
aws ec2 create-key-pair \
  --key-name mongodb-vm-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/mongodb-vm-key.pem
chmod 400 ~/.ssh/mongodb-vm-key.pem
```

### Issue: "ECR repository not found"

```bash
# Create ECR repository
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr create-repository --repository-name todo-app --region us-east-1

# Verify
aws ecr describe-repositories --repository-names todo-app
```

### Issue: "LoadBalancer stuck in pending"

```bash
# Check events
kubectl describe svc todo-app-loadbalancer -n todo-app

# Common causes:
# 1. Subnets not tagged correctly (fixed in terraform)
# 2. AWS account limits reached
# 3. IAM permissions missing for EKS service role

# Wait 3-5 minutes, LoadBalancer provisioning takes time
```

### Issue: "Cannot connect to MongoDB"

```bash
# Check MongoDB VM is running
MONGODB_IP=$(cd terraform && terraform output -raw mongodb_vm_public_ip)
ssh -i ~/.ssh/mongodb-vm-key.pem ubuntu@${MONGODB_IP}

# Check MongoDB status
sudo systemctl status mongod

# Check MongoDB logs
sudo tail -f /var/log/mongodb/mongod.log

# Restart MongoDB if needed
sudo systemctl restart mongod
```

---

## 📚 Additional Resources

- **Complete Guide**: `COMPLETE_GUIDE.md`
- **Quick Start**: `QUICKSTART.md`
- **Requirements Checklist**: `REQUIREMENTS_CHECKLIST.md`
- **GitHub Actions Setup**: `GITHUB_ACTIONS_SETUP.md`
- **Enable Control Plane Logging**: `docs/ENABLE_CONTROL_PLANE_LOGGING.md`

---

## ✅ Deployment Checklist

- [ ] AWS credentials configured
- [ ] SSH key pair created
- [ ] ECR repository created
- [ ] Terraform initialized
- [ ] Infrastructure deployed (15-20 min)
- [ ] kubectl configured
- [ ] Container image built and pushed
- [ ] Application deployed to Kubernetes
- [ ] LoadBalancer URL obtained
- [ ] Application accessible in browser
- [ ] Verification script passed
- [ ] All 12 security vulnerabilities confirmed

**Total Time:** 25-40 minutes (automated) or 40-60 minutes (manual)

---

## 🎯 Summary

**Minimum Requirements:**
1. AWS account with admin permissions
2. AWS CLI, Terraform, kubectl installed
3. SSH key pair in AWS
4. ECR repository created

**Deployment Command:**
```bash
aws configure
./scripts/setup-prerequisites.sh
./scripts/deploy-all.sh
```

**Cost:** ~$218/month (or ~$7/day)

**Time:** 25-40 minutes

**Result:** Fully functional infrastructure with intentional security vulnerabilities for Wiz demo

---

*Last Updated: October 22, 2025*
