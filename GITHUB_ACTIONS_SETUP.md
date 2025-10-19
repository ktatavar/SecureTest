# GitHub Actions Setup Guide

## Quick Start

I've created **3 GitHub Actions workflows** for building and pushing your Docker image. Choose the one that fits your needs:

| Workflow | Registry | Setup Difficulty | Best For |
|----------|----------|------------------|----------|
| `build-and-push.yml` | AWS ECR | Medium | AWS EKS deployments |
| `build-docker-hub.yml` | Docker Hub | Easy | Public images |
| `build-ghcr.yml` | GitHub Container Registry | **Easiest** | GitHub-native |

## Recommended: GitHub Container Registry (Easiest)

### Why GHCR?
- ✅ **Zero setup** - Works out of the box
- ✅ **Free** - Unlimited public images, free private for repos
- ✅ **Integrated** - Built into GitHub
- ✅ **No secrets needed** - Uses `GITHUB_TOKEN`

### Setup Steps (1 minute)

1. **Enable the workflow** (it's already created):
   ```bash
   # The file is already at: .github/workflows/build-ghcr.yml
   # Just commit and push!
   ```

2. **Push your code**:
   ```bash
   git add .
   git commit -m "Add GitHub Actions workflow"
   git push origin main
   ```

3. **That's it!** The workflow will automatically:
   - Build your Docker image
   - Push to `ghcr.io/YOUR_USERNAME/securetest:latest`
   - Create multiple tags (latest, commit SHA, branch name)

4. **Use the image** in Kubernetes:
   ```bash
   # Update k8s/deployment.yaml
   image: ghcr.io/YOUR_USERNAME/securetest:latest
   ```

## Option 2: Docker Hub (Easy)

### Setup Steps (3 minutes)

1. **Create Docker Hub access token**:
   - Go to https://hub.docker.com/settings/security
   - Click "New Access Token"
   - Name it "GitHub Actions"
   - Copy the token

2. **Add secrets to GitHub**:
   - Go to your repo → Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Add `DOCKERHUB_USERNAME` = your Docker Hub username
   - Add `DOCKERHUB_TOKEN` = the token you copied

3. **Enable the workflow**:
   ```bash
   # The file is at: .github/workflows/build-docker-hub.yml
   # Commit and push to trigger
   ```

4. **Use the image**:
   ```bash
   # Update k8s/deployment.yaml
   image: YOUR_USERNAME/todo-app:latest
   ```

## Option 3: AWS ECR (For AWS EKS)

### Setup Steps (10 minutes)

#### Method A: OIDC (Recommended - More Secure)

1. **Create ECR repository**:
   ```bash
   aws ecr create-repository --repository-name todo-app --region us-east-1
   ```

2. **Create IAM OIDC provider** (one-time setup):
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```

3. **Create IAM role** with this trust policy:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
           },
           "StringLike": {
             "token.actions.githubusercontent.com:sub": "repo:YOUR_USERNAME/SecureTest:*"
           }
         }
       }
     ]
   }
   ```

4. **Attach ECR policy** to the role:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ecr:GetAuthorizationToken",
           "ecr:BatchCheckLayerAvailability",
           "ecr:GetDownloadUrlForLayer",
           "ecr:PutImage",
           "ecr:InitiateLayerUpload",
           "ecr:UploadLayerPart",
           "ecr:CompleteLayerUpload"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

5. **Add secret to GitHub**:
   - Go to repo → Settings → Secrets and variables → Actions
   - Add `AWS_ROLE_ARN` = `arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_ROLE_NAME`

#### Method B: Access Keys (Simpler but less secure)

1. **Create ECR repository** (same as above)

2. **Create IAM user** with ECR permissions

3. **Add secrets to GitHub**:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

4. **Modify workflow** to use credentials instead of OIDC

## Workflow Features

All workflows include:
- ✅ **Automatic triggers** on push to main/master
- ✅ **PR builds** for testing before merge
- ✅ **Manual triggers** via workflow_dispatch
- ✅ **Multi-tagging** (latest, branch, commit SHA)
- ✅ **Build caching** for faster builds
- ✅ **Multi-platform** support (amd64, arm64)

## Verifying the Build

1. **Check workflow status**:
   - Go to your repo → Actions tab
   - Click on the latest workflow run
   - View logs and status

2. **Verify image was pushed**:
   ```bash
   # For GHCR
   docker pull ghcr.io/YOUR_USERNAME/securetest:latest
   
   # For Docker Hub
   docker pull YOUR_USERNAME/todo-app:latest
   
   # For ECR
   aws ecr describe-images --repository-name todo-app --region us-east-1
   ```

3. **Test the image locally**:
   ```bash
   docker run -p 3000:3000 \
     -e MONGODB_URI=mongodb://localhost:27017/todoapp \
     ghcr.io/YOUR_USERNAME/securetest:latest
   ```

## Updating Kubernetes Deployment

### Option 1: Manual Update
```bash
# Update deployment.yaml with new image
vim k8s/deployment.yaml

# Change:
# image: todo-app:latest
# To:
# image: ghcr.io/YOUR_USERNAME/securetest:latest

# Apply changes
kubectl apply -f k8s/deployment.yaml
```

### Option 2: Direct kubectl command
```bash
kubectl set image deployment/todo-app -n todo-app \
  todo-app=ghcr.io/YOUR_USERNAME/securetest:latest

# Watch rollout
kubectl rollout status deployment/todo-app -n todo-app
```

### Option 3: Automatic Deployment (Advanced)

Add to your workflow after the build step:

```yaml
- name: Deploy to Kubernetes
  if: github.ref == 'refs/heads/main'
  run: |
    # Configure kubectl
    aws eks update-kubeconfig --region us-east-1 --name wiz-exercise-cluster
    
    # Update deployment
    kubectl set image deployment/todo-app -n todo-app \
      todo-app=${{ steps.login-ecr.outputs.registry }}/todo-app:latest
    
    # Wait for rollout
    kubectl rollout status deployment/todo-app -n todo-app --timeout=5m
```

## Image Pull Secrets (If Using Private Registry)

### For AWS ECR
```bash
kubectl create secret docker-registry ecr-secret \
  --docker-server=ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  -n todo-app

# Update deployment.yaml
spec:
  imagePullSecrets:
  - name: ecr-secret
```

### For Docker Hub (Private Images)
```bash
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  -n todo-app
```

### For GHCR (Private Images)
```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_GITHUB_TOKEN \
  -n todo-app
```

## Troubleshooting

### Build fails with "permission denied"
**Solution**: Check that secrets are configured correctly in GitHub repo settings.

### Image push fails
**Solution**: 
- For ECR: Verify IAM permissions
- For Docker Hub: Check token hasn't expired
- For GHCR: Ensure `packages: write` permission is set

### Kubernetes can't pull image
**Solution**:
1. Verify image exists in registry
2. Check image pull secrets are configured
3. Ensure registry is accessible from cluster

### Workflow doesn't trigger
**Solution**:
1. Check workflow file is in `.github/workflows/`
2. Verify branch name matches trigger (main vs master)
3. Ensure changes are in `app/**` directory

## Best Practices

1. **Use semantic versioning**:
   ```bash
   git tag v1.0.0
   git push --tags
   ```

2. **Test in PR before merging**:
   - Workflows build on PR
   - Review before merging to main

3. **Monitor build times**:
   - Check Actions tab for duration
   - Optimize Dockerfile if builds are slow

4. **Use build cache**:
   - Already configured in workflows
   - Speeds up subsequent builds

5. **Scan for vulnerabilities**:
   - Add Trivy or Snyk to workflow
   - Scan images before pushing

## Next Steps

1. ✅ Choose your preferred registry (recommend GHCR for simplicity)
2. ✅ Set up required secrets (if needed)
3. ✅ Commit and push to trigger first build
4. ✅ Verify image was built and pushed
5. ✅ Update Kubernetes deployment
6. ✅ Test the application

## Summary

**Easiest path**: Use GitHub Container Registry (`build-ghcr.yml`)
- No setup required
- Just commit and push
- Image available at `ghcr.io/YOUR_USERNAME/securetest:latest`

**For production AWS**: Use AWS ECR (`build-and-push.yml`)
- Better integration with EKS
- Private registry in your AWS account
- Requires IAM setup

**For public sharing**: Use Docker Hub (`build-docker-hub.yml`)
- Easy to share
- Well-known registry
- Requires Docker Hub account

All workflows are ready to use - just choose one and push your code!
