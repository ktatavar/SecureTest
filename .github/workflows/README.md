# GitHub Actions Workflows

This directory contains GitHub Actions workflows for building and pushing the Docker image to various container registries.

## Available Workflows

### 1. AWS ECR (`build-and-push.yml`)
Builds and pushes to Amazon Elastic Container Registry.

**Setup Required:**
1. Create an ECR repository:
   ```bash
   aws ecr create-repository --repository-name todo-app --region us-east-1
   ```

2. Set up OIDC for GitHub Actions (recommended):
   - Create an IAM role with ECR push permissions
   - Configure trust relationship for GitHub Actions
   - Add `AWS_ROLE_ARN` secret to your repository

3. Or use AWS credentials (less secure):
   - Add `AWS_ACCESS_KEY_ID` secret
   - Add `AWS_SECRET_ACCESS_KEY` secret

**Secrets Required:**
- `AWS_ROLE_ARN` (for OIDC) or `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`

### 2. Docker Hub (`build-docker-hub.yml`)
Builds and pushes to Docker Hub.

**Setup Required:**
1. Create a Docker Hub account
2. Create an access token in Docker Hub settings
3. Add secrets to your GitHub repository

**Secrets Required:**
- `DOCKERHUB_USERNAME` - Your Docker Hub username
- `DOCKERHUB_TOKEN` - Your Docker Hub access token

### 3. GitHub Container Registry (`build-ghcr.yml`)
Builds and pushes to GitHub Container Registry (ghcr.io).

**Setup Required:**
1. No additional setup needed - uses `GITHUB_TOKEN` automatically
2. Image will be published to `ghcr.io/your-username/your-repo`

**Secrets Required:**
- None (uses built-in `GITHUB_TOKEN`)

## Choosing a Workflow

### Use AWS ECR if:
- ✅ You're deploying to AWS EKS
- ✅ You want private registry in AWS
- ✅ You need AWS integration

### Use Docker Hub if:
- ✅ You want public images
- ✅ You need multi-platform support
- ✅ You want easy sharing

### Use GitHub Container Registry if:
- ✅ You want to keep everything in GitHub
- ✅ You need private images (free for private repos)
- ✅ You want zero setup

## Workflow Triggers

All workflows trigger on:
- **Push** to `main` or `master` branch (when `app/**` changes)
- **Pull Request** to `main` or `master` branch (when `app/**` changes)
- **Manual** trigger via workflow_dispatch

## Image Tags

Each workflow creates multiple tags:
- `latest` - Latest build from main/master branch
- `main` or `master` - Branch name
- `main-abc1234` - Branch name + short commit SHA
- `pr-123` - Pull request number (for PRs)

## Setting Up Secrets

### For AWS ECR (OIDC - Recommended)

1. Create IAM role with trust policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

2. Attach policy to role:
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
        "ecr:BatchGetImage",
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

3. Add secret to GitHub:
   - Go to repository Settings → Secrets and variables → Actions
   - Add `AWS_ROLE_ARN` with value: `arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME`

### For Docker Hub

1. Create access token:
   - Go to Docker Hub → Account Settings → Security
   - Click "New Access Token"
   - Give it a name and copy the token

2. Add secrets to GitHub:
   - Go to repository Settings → Secrets and variables → Actions
   - Add `DOCKERHUB_USERNAME` with your Docker Hub username
   - Add `DOCKERHUB_TOKEN` with the access token

### For GitHub Container Registry

No setup needed! The workflow uses the built-in `GITHUB_TOKEN`.

## Enabling a Workflow

By default, you may want to use only one workflow. To disable others:

1. Rename unused workflows to `.yml.disabled`
2. Or delete them
3. Or keep all and they'll run in parallel

## Using the Built Image

### AWS ECR
```bash
# Update Kubernetes deployment
kubectl set image deployment/todo-app -n todo-app \
  todo-app=ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/todo-app:latest
```

### Docker Hub
```bash
# Update Kubernetes deployment
kubectl set image deployment/todo-app -n todo-app \
  todo-app=YOUR_USERNAME/todo-app:latest
```

### GitHub Container Registry
```bash
# Update Kubernetes deployment
kubectl set image deployment/todo-app -n todo-app \
  todo-app=ghcr.io/YOUR_USERNAME/YOUR_REPO:latest
```

## Automatic Deployment (Optional)

To automatically deploy after building, add to the workflow:

```yaml
- name: Deploy to Kubernetes
  run: |
    aws eks update-kubeconfig --region us-east-1 --name wiz-exercise-cluster
    kubectl set image deployment/todo-app -n todo-app \
      todo-app=${{ steps.login-ecr.outputs.registry }}/todo-app:latest
    kubectl rollout status deployment/todo-app -n todo-app
```

## Monitoring Builds

1. Go to your repository on GitHub
2. Click "Actions" tab
3. View workflow runs and logs

## Troubleshooting

### Build fails with "permission denied"
- Check that secrets are set correctly
- Verify IAM role/token has correct permissions

### Image not found in registry
- Check that workflow completed successfully
- Verify registry URL is correct
- Ensure you're logged in to the registry

### Kubernetes can't pull image
- Check image pull secrets are configured
- Verify image tag exists in registry
- Ensure registry is accessible from cluster

## Best Practices

1. **Use OIDC for AWS** - More secure than access keys
2. **Use access tokens** - Don't use passwords for Docker Hub
3. **Tag with commit SHA** - For traceability
4. **Enable branch protection** - Require PR reviews before merge
5. **Use pull request builds** - Test before merging
6. **Cache layers** - Speeds up builds (already configured)

## Next Steps

1. Choose your preferred registry
2. Set up required secrets
3. Push code to trigger a build
4. Update Kubernetes deployment with new image
5. Verify application is running

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [Docker Hub Documentation](https://docs.docker.com/docker-hub/)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
