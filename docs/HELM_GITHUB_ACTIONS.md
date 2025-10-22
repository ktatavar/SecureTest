# Helm Chart GitHub Actions

This document explains the GitHub Actions workflows for Helm chart deployment and publishing.

## 📋 Available Workflows

### 1. Helm Deploy (`helm-deploy.yml`)
Deploys the Helm chart to EKS cluster.

**Status**: 🔴 **DISABLED BY DEFAULT**

### 2. Helm Publish (`helm-publish.yml`)
Publishes the Helm chart to various registries.

**Status**: 🔴 **DISABLED BY DEFAULT**

---

## 🔧 Prerequisites

Before enabling these workflows, ensure you have:

### Required Secrets

| Secret | Description | How to Get |
|--------|-------------|------------|
| `AWS_ROLE_ARN` | IAM role ARN for OIDC | See [AWS OIDC Setup](#aws-oidc-setup) |
| `GITHUB_TOKEN` | GitHub token | Automatically provided |

### Required Resources

- ✅ EKS cluster deployed and running
- ✅ MongoDB VM deployed
- ✅ Terraform state accessible
- ✅ AWS OIDC provider configured
- ✅ IAM role with EKS permissions

---

## 🚀 How to Enable Workflows

### Option 1: Enable Helm Deploy Workflow

**Step 1: Edit `.github/workflows/helm-deploy.yml`**

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

**Step 2: Remove the `if: false` condition**

```yaml
# Change this:
if: false  # DISABLED

# To this:
# (remove the line entirely or change to 'if: true')
```

**Step 3: Commit and push**

```bash
git add .github/workflows/helm-deploy.yml
git commit -m "Enable Helm deploy workflow"
git push
```

### Option 2: Enable Helm Publish Workflow

**Step 1: Edit `.github/workflows/helm-publish.yml`**

```yaml
# Change this:
# on:
#   release:
#     types: [published]

# To this:
on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      publish_method:
        description: 'Publishing method'
        required: true
        default: 'github-release'
        type: choice
        options:
          - github-release
          - oci-registry
          - helm-repo
          - all
```

**Step 2: Remove the `if: false` condition**

```yaml
# Change this:
if: false  # DISABLED

# To this:
# (remove the line entirely)
```

**Step 3: Commit and push**

```bash
git add .github/workflows/helm-publish.yml
git commit -m "Enable Helm publish workflow"
git push
```

---

## 🔐 AWS OIDC Setup

### Create OIDC Provider

```bash
# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create OIDC provider (if not exists)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### Create IAM Role

```bash
# Create trust policy
cat > trust-policy.json << EOF
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
          "token.actions.githubusercontent.com:sub": "repo:ktatavar/SecureTest:*"
        }
      }
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name GitHubActionsHelmDeploy \
  --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name GitHubActionsHelmDeploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws iam attach-role-policy \
  --role-name GitHubActionsHelmDeploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

# Create custom policy for Terraform state access
cat > terraform-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-bucket/*",
        "arn:aws:s3:::terraform-state-bucket"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name GitHubActionsHelmDeploy \
  --policy-name TerraformStateAccess \
  --policy-document file://terraform-policy.json

# Get role ARN
aws iam get-role --role-name GitHubActionsHelmDeploy --query 'Role.Arn' --output text
```

### Add Secret to GitHub

```bash
# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name GitHubActionsHelmDeploy --query 'Role.Arn' --output text)

# Add to GitHub secrets using gh CLI
gh secret set AWS_ROLE_ARN --body "$ROLE_ARN"

# Or manually:
# 1. Go to https://github.com/ktatavar/SecureTest/settings/secrets/actions
# 2. Click "New repository secret"
# 3. Name: AWS_ROLE_ARN
# 4. Value: <paste role ARN>
```

---

## 📖 Usage

### Deploy Helm Chart

Once enabled, deploy via GitHub Actions UI:

1. Go to **Actions** tab
2. Select **Helm - Deploy to EKS**
3. Click **Run workflow**
4. Select options:
   - **Environment**: dev/staging/prod
   - **Chart version**: 1.0.0
   - **Chart source**: local/git/oci/repo
5. Click **Run workflow**

**Or via GitHub CLI:**

```bash
gh workflow run helm-deploy.yml \
  -f environment=dev \
  -f chart_version=1.0.0 \
  -f chart_source=local
```

### Publish Helm Chart

**Option A: Automatic on Release**

```bash
# Create a release
gh release create v1.0.0 \
  --title "v1.0.0" \
  --notes "Release notes here"

# Workflow runs automatically
```

**Option B: Manual Trigger**

```bash
gh workflow run helm-publish.yml \
  -f publish_method=all
```

---

## 🔍 Workflow Details

### Helm Deploy Workflow

**Triggers:**
- Manual workflow dispatch
- Push to `main` branch (when `helm/**` changes)

**Steps:**
1. ✅ Checkout code
2. ✅ Configure AWS credentials (OIDC)
3. ✅ Install Helm and kubectl
4. ✅ Configure kubectl for EKS
5. ✅ Get MongoDB IP from Terraform
6. ✅ Lint and package chart (if local)
7. ✅ Prepare chart source (local/git/oci/repo)
8. ✅ Check if release exists
9. ✅ Deploy with Helm (install or upgrade)
10. ✅ Wait for pods to be ready
11. ✅ Get LoadBalancer URL
12. ✅ Test application health
13. ✅ Verify wizexercise.txt
14. ✅ Create deployment summary

**Inputs:**
- `environment`: Deployment environment (dev/staging/prod)
- `chart_version`: Helm chart version
- `chart_source`: Chart source (local/git/oci/repo)

**Outputs:**
- Deployment summary in GitHub Actions UI
- LoadBalancer URL
- Application health status

### Helm Publish Workflow

**Triggers:**
- Release published
- Manual workflow dispatch

**Steps:**
1. ✅ Checkout code
2. ✅ Install Helm
3. ✅ Get chart version
4. ✅ Lint Helm chart
5. ✅ Package Helm chart
6. ✅ Publish to GitHub Release
7. ✅ Publish to OCI Registry (GHCR)
8. ✅ Publish to Helm Repository (GitHub Pages)
9. ✅ Create publishing summary

**Inputs:**
- `publish_method`: Publishing method (github-release/oci-registry/helm-repo/all)

**Outputs:**
- Chart published to selected registries
- Installation instructions in summary

---

## 🧪 Testing Workflows Locally

### Test with act

```bash
# Install act
brew install act  # macOS
# or
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Test deploy workflow
act workflow_dispatch \
  -W .github/workflows/helm-deploy.yml \
  -s AWS_ROLE_ARN="arn:aws:iam::123456789012:role/GitHubActionsHelmDeploy"

# Test publish workflow
act workflow_dispatch \
  -W .github/workflows/helm-publish.yml
```

---

## 🔧 Troubleshooting

### Issue: "Role ARN not found"

**Solution:**
```bash
# Verify secret exists
gh secret list

# Set secret
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::123456789012:role/GitHubActionsHelmDeploy"
```

### Issue: "Failed to get MongoDB IP"

**Solution:**
- Ensure Terraform state is accessible
- Check IAM role has S3 permissions for Terraform state
- Verify MongoDB VM is deployed

### Issue: "kubectl: connection refused"

**Solution:**
- Verify EKS cluster is running
- Check IAM role has EKS permissions
- Ensure cluster endpoint is accessible

### Issue: "Helm release already exists"

**Solution:**
- Workflow automatically detects and upgrades
- Or manually delete: `helm uninstall todo-app -n todo-app`

---

## 📊 Workflow Comparison

| Feature | Helm Deploy | Helm Publish |
|---------|-------------|--------------|
| **Purpose** | Deploy to EKS | Publish chart |
| **Trigger** | Manual/Push | Release/Manual |
| **AWS Access** | Required | Not required |
| **EKS Access** | Required | Not required |
| **Terraform** | Required | Not required |
| **Outputs** | Deployment status | Published chart |

---

## 🎯 Best Practices

### 1. Use Separate Environments

```yaml
# Deploy to dev
gh workflow run helm-deploy.yml -f environment=dev

# Deploy to prod
gh workflow run helm-deploy.yml -f environment=prod
```

### 2. Version Your Charts

```yaml
# Update Chart.yaml version
version: 1.1.0

# Publish
gh release create v1.1.0

# Deploy specific version
gh workflow run helm-deploy.yml -f chart_version=1.1.0 -f chart_source=git
```

### 3. Test Before Production

```bash
# Deploy to dev first
gh workflow run helm-deploy.yml -f environment=dev

# Verify
kubectl get all -n todo-app

# Then deploy to prod
gh workflow run helm-deploy.yml -f environment=prod
```

### 4. Monitor Deployments

```bash
# Watch workflow
gh run watch

# View logs
gh run view --log

# Check deployment
kubectl get pods -n todo-app -w
```

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Helm Documentation](https://helm.sh/docs/)
- [AWS OIDC for GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

---

## ✅ Summary

**To Enable:**
1. Uncomment `on:` triggers in workflow files
2. Remove `if: false` conditions
3. Set up AWS OIDC and IAM role
4. Add `AWS_ROLE_ARN` secret to GitHub
5. Commit and push changes

**To Use:**
- Deploy: GitHub Actions UI or `gh workflow run helm-deploy.yml`
- Publish: Create release or `gh workflow run helm-publish.yml`

**Workflows are disabled by default for safety!**

---

*Last Updated: October 22, 2025*
