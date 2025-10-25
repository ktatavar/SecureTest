# Deployment Guide - New AWS Account Setup

This guide provides step-by-step instructions to deploy the complete infrastructure and application stack in a new AWS account.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [AWS Account Setup](#aws-account-setup)
3. [GitHub Repository Setup](#github-repository-setup)
4. [GitHub Actions OIDC Configuration](#github-actions-oidc-configuration)
5. [Deploy Infrastructure (Pipeline 1)](#deploy-infrastructure-pipeline-1)
6. [Deploy Application (Pipeline 2)](#deploy-application-pipeline-2)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)
9. [Cleanup](#cleanup)

---

## Prerequisites

### Required Tools
- **AWS CLI** (v2.x or later)
  ```bash
  aws --version
  ```
- **Terraform** (v1.5.x or later)
  ```bash
  terraform --version
  ```
- **kubectl** (v1.28.x or later)
  ```bash
  kubectl version --client
  ```
- **Helm** (v3.13.x or later)
  ```bash
  helm version
  ```
- **GitHub CLI** (optional but recommended)
  ```bash
  gh --version
  ```
- **Git**
  ```bash
  git --version
  ```

### AWS Account Requirements
- Active AWS account with administrative access
- AWS CLI configured with credentials
- Sufficient service limits:
  - VPCs: At least 1 available (we use 1 reusable VPC)
  - EKS clusters: At least 1
  - EC2 instances: At least 3 (2 for EKS nodes, 1 for MongoDB)
  - Elastic IPs: At least 2
  - NAT Gateways: At least 1

### GitHub Requirements
- GitHub account
- Repository with this code (can be forked or new)
- Ability to configure GitHub Actions secrets

---

## AWS Account Setup

### Step 1: Configure AWS CLI

```bash
# Configure AWS credentials
aws configure

# Verify configuration
aws sts get-caller-identity

# Note your AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
```

### Step 2: Set AWS Region

```bash
# Set your preferred region (us-east-1 recommended)
export AWS_REGION="us-east-1"
echo "AWS Region: $AWS_REGION"
```

### Step 3: Verify Service Limits

```bash
# Check VPC limit
aws ec2 describe-account-attributes \
  --attribute-names max-vpcs \
  --region $AWS_REGION

# Check EKS clusters
aws eks list-clusters --region $AWS_REGION

# Check current VPC usage
aws ec2 describe-vpcs --region $AWS_REGION --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table
```

---

## GitHub Repository Setup

### Step 1: Fork or Clone Repository

**Option A: Fork the repository (recommended)**
```bash
# Via GitHub UI: Click "Fork" button on the repository page
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/SecureTest.git
cd SecureTest
```

**Option B: Create new repository with this code**
```bash
# Create new repo on GitHub, then:
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME

# Copy all files from this project
# Then commit and push
git add .
git commit -m "Initial commit"
git push origin main
```

### Step 2: Update Repository-Specific Values

Edit the following files to match your setup:

**1. Update GitHub repository references in workflows:**
```bash
# Find and replace repository owner/name in workflow files
grep -r "ktatavar/SecureTest" .github/workflows/

# Update to your repository
find .github/workflows -type f -exec sed -i '' 's/ktatavar\/SecureTest/YOUR_USERNAME\/YOUR_REPO/g' {} +
```

**2. Update AWS Account ID in workflows (if hardcoded):**
```bash
# Check for hardcoded account IDs
grep -r "512231857943" .github/workflows/

# Replace with your account ID
find .github/workflows -type f -exec sed -i '' "s/512231857943/$AWS_ACCOUNT_ID/g" {} +
```

**3. Update wizexercise.txt with your name:**
```bash
echo "YOUR_NAME" > app/wizexercise.txt
```

**4. Commit changes:**
```bash
git add .
git commit -m "Update repository configuration for new account"
git push origin main
```

---

## GitHub Actions OIDC Configuration

This is the most critical step. GitHub Actions will use OIDC to authenticate with AWS without storing credentials.

### Step 1: Create OIDC Provider in AWS

```bash
# Set your GitHub username/org
export GITHUB_ORG="YOUR_USERNAME"
export GITHUB_REPO="YOUR_REPO_NAME"

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region $AWS_REGION

# Verify creation
aws iam list-open-id-connect-providers
```

### Step 2: Create IAM Role for GitHub Actions

```bash
# Create trust policy file
cat > /tmp/github-actions-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name GitHubActionsECRRole \
  --assume-role-policy-document file:///tmp/github-actions-trust-policy.json \
  --description "Role for GitHub Actions to deploy infrastructure and applications"

# Attach required policies
aws iam attach-role-policy \
  --role-name GitHubActionsECRRole \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

aws iam attach-role-policy \
  --role-name GitHubActionsECRRole \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

# Verify role creation
aws iam get-role --role-name GitHubActionsECRRole
```

### Step 3: Add Your User to Role Trust Policy (for kubectl access)

```bash
# Get your IAM user ARN
export USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
echo "Your IAM User ARN: $USER_ARN"

# Update trust policy to include your user
cat > /tmp/github-actions-trust-policy-updated.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${USER_ARN}"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Update the role
aws iam update-assume-role-policy \
  --role-name GitHubActionsECRRole \
  --policy-document file:///tmp/github-actions-trust-policy-updated.json
```

---

## Deploy Infrastructure (Pipeline 1)

### Step 1: Verify Terraform Configuration

```bash
cd terraform

# Check main.tf for any hardcoded values
grep -n "512231857943" *.tf
grep -n "ktatavar" *.tf

# Update if necessary
```

### Step 2: Run Pipeline 1 via GitHub Actions

**Option A: Via GitHub UI**
1. Go to your repository on GitHub
2. Click "Actions" tab
3. Select "Pipeline 1 - Infrastructure (IaC)"
4. Click "Run workflow"
5. Select branch: `main`
6. Click "Run workflow"

**Option B: Via GitHub CLI**
```bash
cd /path/to/SecureTest

# Trigger Pipeline 1
gh workflow run terraform-deploy.yml

# Watch the workflow
gh run watch

# Or list recent runs
gh run list --workflow=terraform-deploy.yml --limit 5
```

**Option C: Via Git Push (automatic trigger)**
```bash
# Make a change to trigger the workflow
touch terraform/trigger_deploy.txt
git add terraform/trigger_deploy.txt
git commit -m "Trigger infrastructure deployment"
git push origin main

# Watch in GitHub Actions UI
```

### Step 3: Monitor Deployment

```bash
# Watch the workflow progress
gh run watch

# Or check status
gh run list --workflow=terraform-deploy.yml --limit 1

# View logs if needed
gh run view --log
```

**Expected Duration:** 15-20 minutes

**What Gets Created:**
- VPC with tag `wiz-exercise-vpc` (reusable)
- Public and private subnets
- Internet Gateway and NAT Gateway
- EKS cluster with 2 t3.medium nodes
- MongoDB EC2 instance (t3.medium, Ubuntu 18.04)
- S3 bucket for MongoDB backups
- Security groups (intentionally permissive)

### Step 4: Verify Infrastructure

```bash
# List all resources created
aws eks list-clusters --region $AWS_REGION

aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=mongodb-vm-outdated" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \
  --output table \
  --region $AWS_REGION

aws s3 ls | grep mongodb-backups

aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=wiz-exercise-vpc" \
  --query 'Vpcs[*].[VpcId,CidrBlock]' \
  --output table \
  --region $AWS_REGION
```

### Step 5: Get Cluster Name

```bash
# Get the cluster name (it will have a timestamp)
export CLUSTER_NAME=$(aws eks list-clusters --region $AWS_REGION --query 'clusters[0]' --output text)
echo "EKS Cluster Name: $CLUSTER_NAME"

# Configure kubectl
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActionsECRRole

# Verify access
kubectl get nodes
```

---

## Deploy Application (Pipeline 2)

### Step 1: Update Helm Workflow with Cluster Name

```bash
# Update the cluster name in helm-deploy.yml
export CLUSTER_NAME=$(aws eks list-clusters --region $AWS_REGION --query 'clusters[0]' --output text)

# Edit .github/workflows/helm-deploy.yml
# Update line 60: EKS_CLUSTER_NAME: <your-cluster-name>
sed -i '' "s/EKS_CLUSTER_NAME: .*/EKS_CLUSTER_NAME: $CLUSTER_NAME/" .github/workflows/helm-deploy.yml

# Commit the change
git add .github/workflows/helm-deploy.yml
git commit -m "Update cluster name in Helm workflow"
git push origin main
```

### Step 2: Run Pipeline 2 via GitHub Actions

**Option A: Via GitHub UI**
1. Go to your repository on GitHub
2. Click "Actions" tab
3. Select "Pipeline 2 - Application Build & Deploy"
4. Click "Run workflow"
5. Select environment: `dev`
6. Click "Run workflow"

**Option B: Via GitHub CLI**
```bash
# Trigger Pipeline 2
gh workflow run app-deploy.yml -f environment=dev

# Watch the workflow
gh run watch
```

### Step 3: Monitor Deployment

```bash
# Watch the workflow
gh run watch

# Check status
gh run list --workflow=app-deploy.yml --limit 1
```

**Expected Duration:** 5-10 minutes

**What Happens:**
1. Container image built from `app/` directory
2. Image pushed to Amazon ECR
3. Trivy security scan (soft-fail)
4. Helm chart deployed to EKS
5. 3 application pods created
6. LoadBalancer service provisioned

### Step 4: Verify Application Deployment

```bash
# Check pods
kubectl get pods -n todo-app

# Check services
kubectl get svc -n todo-app

# Get LoadBalancer URL
export LB_URL=$(kubectl get svc todo-app-loadbalancer -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://$LB_URL"

# Wait for LoadBalancer to be ready (2-5 minutes)
# Then test the application
curl http://$LB_URL

# Test wizexercise.txt
curl http://$LB_URL/wizexercise.txt
```

---

## Verification

### Complete System Check

```bash
#!/bin/bash

echo "=========================================="
echo "Complete System Verification"
echo "=========================================="
echo ""

# 1. Infrastructure
echo "1. Checking Infrastructure..."
echo ""

echo "VPC:"
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=wiz-exercise-vpc" \
  --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table \
  --region $AWS_REGION

echo ""
echo "EKS Cluster:"
CLUSTER_NAME=$(aws eks list-clusters --region $AWS_REGION --query 'clusters[0]' --output text)
aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --query 'cluster.[name,status,endpoint]' \
  --output table \
  --region $AWS_REGION

echo ""
echo "MongoDB VM:"
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=mongodb-vm-outdated" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]' \
  --output table \
  --region $AWS_REGION

echo ""
echo "S3 Bucket:"
aws s3 ls | grep mongodb-backups

# 2. Kubernetes
echo ""
echo "2. Checking Kubernetes..."
echo ""

echo "Nodes:"
kubectl get nodes

echo ""
echo "Pods:"
kubectl get pods -n todo-app

echo ""
echo "Services:"
kubectl get svc -n todo-app

# 3. Application
echo ""
echo "3. Checking Application..."
echo ""

LB_URL=$(kubectl get svc todo-app-loadbalancer -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "LoadBalancer URL: http://$LB_URL"

echo ""
echo "Testing application health:"
curl -s http://$LB_URL/health | jq '.'

echo ""
echo "Testing wizexercise.txt:"
curl -s http://$LB_URL/wizexercise.txt

echo ""
echo "=========================================="
echo "Verification Complete!"
echo "=========================================="
```

### Expected Results

**Infrastructure:**
- ✅ 1 VPC with tag `wiz-exercise-vpc`
- ✅ EKS cluster in ACTIVE state
- ✅ MongoDB VM in running state
- ✅ S3 bucket exists

**Kubernetes:**
- ✅ 2 nodes in Ready state
- ✅ 3 pods in Running state (todo-app namespace)
- ✅ 2 services (ClusterIP and LoadBalancer)

**Application:**
- ✅ LoadBalancer has external hostname
- ✅ `/health` endpoint returns `{"status":"healthy"}`
- ✅ `/wizexercise.txt` returns your name

---

## Troubleshooting

### Issue 1: OIDC Authentication Fails

**Symptom:**
```
Error: Could not load credentials from any providers
```

**Solution:**
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Verify role exists
aws iam get-role --role-name GitHubActionsECRRole

# Check trust policy
aws iam get-role --role-name GitHubActionsECRRole --query 'Role.AssumeRolePolicyDocument'

# Recreate if necessary (see Step 2 of OIDC Configuration)
```

### Issue 2: EKS Cluster Endpoint Not Accessible

**Symptom:**
```
dial tcp: lookup <cluster-endpoint>: no such host
```

**Solution:**
```bash
# Check if public access is enabled
aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --query 'cluster.resourcesVpcConfig.[endpointPublicAccess,endpointPrivateAccess]' \
  --output table

# Enable public access if disabled
aws eks update-cluster-config \
  --name $CLUSTER_NAME \
  --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true \
  --region $AWS_REGION

# Wait 5-10 minutes for update to complete
aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --query 'cluster.status' \
  --output text
```

### Issue 3: kubectl Authentication Fails

**Symptom:**
```
error: You must be logged in to the server (the server has asked for the client to provide credentials)
```

**Solution:**
```bash
# Update kubeconfig with role ARN
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActionsECRRole

# Test access
kubectl get nodes
```

### Issue 4: Pods Not Starting (ImagePullBackOff)

**Symptom:**
```
kubectl get pods -n todo-app
NAME                        READY   STATUS             RESTARTS   AGE
todo-app-xxx                0/1     ImagePullBackOff   0          2m
```

**Solution:**
```bash
# Check pod details
kubectl describe pod -n todo-app <pod-name>

# Verify ECR repository exists
aws ecr describe-repositories --repository-names todo-app --region $AWS_REGION

# Verify images exist
aws ecr describe-images --repository-name todo-app --region $AWS_REGION

# If images don't exist, re-run Pipeline 2
gh workflow run app-deploy.yml -f environment=dev
```

### Issue 5: VPC Limit Reached

**Symptom:**
```
Error: VpcLimitExceeded: The maximum number of VPCs has been reached
```

**Solution:**
```bash
# List all VPCs
aws ec2 describe-vpcs --region $AWS_REGION --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],IsDefault]' --output table

# Delete unused VPCs (be careful!)
# Or request limit increase from AWS Support

# The VPC reuse strategy should prevent this issue
# It will reuse existing VPC with tag "wiz-exercise-vpc"
```

### Issue 6: wizexercise.txt Returns 404

**Symptom:**
```
curl http://<loadbalancer>/wizexercise.txt
Cannot GET /wizexercise.txt
```

**Solution:**
```bash
# Verify file exists in container
kubectl exec -n todo-app deployment/todo-app -- cat /app/wizexercise.txt

# Verify route exists in server.js
kubectl exec -n todo-app deployment/todo-app -- cat /app/server.js | grep wizexercise

# If route is missing, the code needs to be updated
# Check app/server.js for the /wizexercise.txt route

# Force pod restart to pick up new image
kubectl rollout restart deployment/todo-app -n todo-app
kubectl rollout status deployment/todo-app -n todo-app
```

### Issue 7: Terraform State Lock

**Symptom:**
```
Error: Error acquiring the state lock
```

**Solution:**
```bash
# This happens if a previous Terraform run was interrupted
# Wait 5 minutes for lock to expire, or force unlock (use with caution)

cd terraform
terraform force-unlock <LOCK_ID>
```

---

## Cleanup

### Option 1: Destroy Everything (Complete Cleanup)

```bash
# 1. Delete Kubernetes resources first
kubectl delete namespace todo-app

# 2. Run Terraform destroy
cd terraform
terraform destroy -auto-approve

# 3. Delete ECR repository
aws ecr delete-repository \
  --repository-name todo-app \
  --force \
  --region $AWS_REGION

# 4. Delete IAM role
aws iam detach-role-policy \
  --role-name GitHubActionsECRRole \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

aws iam detach-role-policy \
  --role-name GitHubActionsECRRole \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

aws iam delete-role --role-name GitHubActionsECRRole

# 5. Delete OIDC provider
OIDC_ARN=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text)
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $OIDC_ARN

# 6. Verify cleanup
aws eks list-clusters --region $AWS_REGION
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=wiz-exercise-vpc" --region $AWS_REGION
```

### Option 2: Keep VPC, Destroy Everything Else

```bash
# This preserves the VPC for future deployments

# 1. Delete Kubernetes resources
kubectl delete namespace todo-app

# 2. Delete EKS cluster (but keep VPC)
cd terraform
terraform destroy -target=module.eks -auto-approve
terraform destroy -target=aws_instance.mongodb_vm -auto-approve
terraform destroy -target=aws_s3_bucket.mongodb_backups -auto-approve

# VPC will be reused in next deployment
```

### Option 3: Cleanup Script

```bash
#!/bin/bash

echo "=========================================="
echo "Cleanup Script"
echo "=========================================="
echo ""

read -p "This will destroy ALL resources. Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo "Starting cleanup..."

# Delete Kubernetes resources
echo "Deleting Kubernetes resources..."
kubectl delete namespace todo-app --ignore-not-found=true

# Destroy Terraform resources
echo "Destroying Terraform resources..."
cd terraform
terraform destroy -auto-approve

# Delete ECR
echo "Deleting ECR repository..."
aws ecr delete-repository --repository-name todo-app --force --region $AWS_REGION 2>/dev/null

# Delete IAM role
echo "Deleting IAM role..."
aws iam detach-role-policy --role-name GitHubActionsECRRole --policy-arn arn:aws:iam::aws:policy/PowerUserAccess 2>/dev/null
aws iam detach-role-policy --role-name GitHubActionsECRRole --policy-arn arn:aws:iam::aws:policy/IAMFullAccess 2>/dev/null
aws iam delete-role --role-name GitHubActionsECRRole 2>/dev/null

# Delete OIDC provider
echo "Deleting OIDC provider..."
OIDC_ARN=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text)
if [ -n "$OIDC_ARN" ]; then
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $OIDC_ARN
fi

echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
```

---

## Summary Checklist

Use this checklist to track your deployment progress:

### Pre-Deployment
- [ ] AWS CLI installed and configured
- [ ] Terraform installed
- [ ] kubectl installed
- [ ] Helm installed
- [ ] GitHub repository created/forked
- [ ] Repository values updated (account ID, repo name, etc.)

### AWS Setup
- [ ] AWS Account ID noted
- [ ] AWS Region set
- [ ] Service limits verified
- [ ] OIDC provider created
- [ ] IAM role created (GitHubActionsECRRole)
- [ ] Policies attached to role
- [ ] User added to role trust policy

### Pipeline 1 (Infrastructure)
- [ ] Terraform configuration verified
- [ ] Pipeline 1 triggered
- [ ] Deployment completed successfully
- [ ] VPC created
- [ ] EKS cluster created
- [ ] MongoDB VM created
- [ ] S3 bucket created
- [ ] kubectl configured and working

### Pipeline 2 (Application)
- [ ] Cluster name updated in helm-deploy.yml
- [ ] Pipeline 2 triggered
- [ ] Container image built and pushed
- [ ] Helm deployment successful
- [ ] Pods running (3/3)
- [ ] LoadBalancer provisioned
- [ ] Application accessible
- [ ] wizexercise.txt accessible

### Verification
- [ ] All infrastructure resources verified
- [ ] Kubernetes cluster accessible
- [ ] Application responding to requests
- [ ] wizexercise.txt returns correct content
- [ ] Security scans completed (soft-fail)

---

## Quick Reference Commands

```bash
# Get AWS Account ID
aws sts get-caller-identity --query Account --output text

# Get Cluster Name
aws eks list-clusters --region us-east-1 --query 'clusters[0]' --output text

# Configure kubectl
aws eks update-kubeconfig --name <cluster-name> --region us-east-1 --role-arn arn:aws:iam::<account-id>:role/GitHubActionsECRRole

# Get LoadBalancer URL
kubectl get svc todo-app-loadbalancer -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Trigger Pipeline 1
gh workflow run terraform-deploy.yml

# Trigger Pipeline 2
gh workflow run app-deploy.yml -f environment=dev

# Watch workflow
gh run watch

# Check pods
kubectl get pods -n todo-app

# Restart deployment
kubectl rollout restart deployment/todo-app -n todo-app
```

---

## Support and Additional Resources

- **AWS EKS Documentation**: https://docs.aws.amazon.com/eks/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **GitHub Actions OIDC**: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
- **Helm Documentation**: https://helm.sh/docs/

---

**Last Updated:** October 25, 2025
**Version:** 1.0
