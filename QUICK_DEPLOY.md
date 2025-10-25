# Quick Deployment Guide - New AWS Account

This is a condensed version for experienced users. For detailed instructions, see [DEPLOY_NEW_ACCOUNT.md](./DEPLOY_NEW_ACCOUNT.md).

## Prerequisites
- AWS CLI, Terraform, kubectl, Helm, Git installed
- AWS account with admin access
- GitHub account and repository

## 1. Setup Environment Variables (5 minutes)

```bash
# Set your values
export AWS_ACCOUNT_ID="YOUR_ACCOUNT_ID"
export AWS_REGION="us-east-1"
export GITHUB_ORG="YOUR_USERNAME"
export GITHUB_REPO="YOUR_REPO_NAME"

# Verify AWS access
aws sts get-caller-identity
```

## 2. Create OIDC Provider (2 minutes)

```bash
# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create trust policy
cat > /tmp/trust-policy.json << EOF
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
        "AWS": "$(aws sts get-caller-identity --query Arn --output text)"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name GitHubActionsECRRole \
  --assume-role-policy-document file:///tmp/trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name GitHubActionsECRRole \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

aws iam attach-role-policy \
  --role-name GitHubActionsECRRole \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

## 3. Update Repository (3 minutes)

```bash
cd /path/to/your/repo

# Update wizexercise.txt
echo "YOUR_NAME" > app/wizexercise.txt

# Update repository references (if needed)
find .github/workflows -type f -exec sed -i '' "s/ktatavar\/SecureTest/${GITHUB_ORG}\/${GITHUB_REPO}/g" {} +

# Commit
git add .
git commit -m "Configure for new account"
git push origin main
```

## 4. Deploy Infrastructure - Pipeline 1 (15-20 minutes)

```bash
# Trigger via GitHub CLI
gh workflow run terraform-deploy.yml

# Watch progress
gh run watch

# Or trigger via GitHub UI:
# Actions → Pipeline 1 - Infrastructure (IaC) → Run workflow
```

**Wait for completion, then verify:**
```bash
# Get cluster name
export CLUSTER_NAME=$(aws eks list-clusters --region $AWS_REGION --query 'clusters[0]' --output text)
echo "Cluster: $CLUSTER_NAME"

# Configure kubectl
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActionsECRRole

# Verify
kubectl get nodes
```

## 5. Update Helm Workflow (1 minute)

```bash
# Update cluster name in workflow
sed -i '' "s/EKS_CLUSTER_NAME: .*/EKS_CLUSTER_NAME: $CLUSTER_NAME/" .github/workflows/helm-deploy.yml

git add .github/workflows/helm-deploy.yml
git commit -m "Update cluster name"
git push origin main
```

## 6. Deploy Application - Pipeline 2 (5-10 minutes)

```bash
# Trigger via GitHub CLI
gh workflow run app-deploy.yml -f environment=dev

# Watch progress
gh run watch

# Or trigger via GitHub UI:
# Actions → Pipeline 2 - Application Build & Deploy → Run workflow
```

**Wait for completion, then verify:**
```bash
# Check pods
kubectl get pods -n todo-app

# Get LoadBalancer URL
export LB_URL=$(kubectl get svc todo-app-loadbalancer -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://$LB_URL"

# Test (wait 2-3 minutes for LoadBalancer to be ready)
curl http://$LB_URL/health
curl http://$LB_URL/wizexercise.txt
```

## 7. Verification Checklist

```bash
# Quick verification script
cat << 'EOF' | bash
echo "=== Infrastructure ==="
aws eks list-clusters --region $AWS_REGION
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=wiz-exercise-vpc" --query 'Vpcs[*].VpcId' --output text

echo -e "\n=== Kubernetes ==="
kubectl get nodes
kubectl get pods -n todo-app

echo -e "\n=== Application ==="
LB_URL=$(kubectl get svc todo-app-loadbalancer -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "URL: http://$LB_URL"
curl -s http://$LB_URL/health | jq '.'
curl -s http://$LB_URL/wizexercise.txt
EOF
```

## Troubleshooting Quick Fixes

### EKS endpoint not accessible
```bash
aws eks update-cluster-config \
  --name $CLUSTER_NAME \
  --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true \
  --region $AWS_REGION
# Wait 5-10 minutes
```

### kubectl auth fails
```bash
aws eks update-kubeconfig \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActionsECRRole
```

### Pods not starting
```bash
kubectl describe pod -n todo-app $(kubectl get pods -n todo-app -o name | head -1)
kubectl rollout restart deployment/todo-app -n todo-app
```

### wizexercise.txt returns 404
```bash
kubectl rollout restart deployment/todo-app -n todo-app
kubectl rollout status deployment/todo-app -n todo-app
# Wait 1-2 minutes, then test again
```

## Cleanup

```bash
# Delete everything
kubectl delete namespace todo-app
cd terraform && terraform destroy -auto-approve
aws ecr delete-repository --repository-name todo-app --force --region $AWS_REGION
aws iam detach-role-policy --role-name GitHubActionsECRRole --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
aws iam detach-role-policy --role-name GitHubActionsECRRole --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
aws iam delete-role --role-name GitHubActionsECRRole
OIDC_ARN=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text)
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $OIDC_ARN
```

## Total Time: ~30-40 minutes

- Setup: 10 minutes
- Pipeline 1: 15-20 minutes
- Pipeline 2: 5-10 minutes
- Verification: 5 minutes

---

**For detailed instructions and troubleshooting, see [DEPLOY_NEW_ACCOUNT.md](./DEPLOY_NEW_ACCOUNT.md)**
