# Wiz Technical Exercise - Quick Deployment Guide

## 📋 Overview

This guide provides a streamlined deployment process for the Wiz Technical Exercise infrastructure.

## 🎯 What Gets Deployed

### Infrastructure Components
1. **VPC & Networking**
   - Public subnet (Load Balancer)
   - Private subnet (Kubernetes pods)
   - Internet Gateway & NAT Gateway

2. **MongoDB VM** (Intentionally Insecure)
   - Ubuntu 18.04 LTS (OUTDATED)
   - MongoDB 4.4.18 (OUTDATED)
   - Public IP with SSH exposed
   - Overly permissive IAM role

3. **EKS Kubernetes Cluster**
   - 2-4 worker nodes in private subnet
   - Network policies configured
   - LoadBalancer service for public access

4. **S3 Backup Bucket** (Intentionally Insecure)
   - Public read access
   - Public listing enabled
   - Daily automated backups

5. **Todo List Application**
   - Node.js + Express + MongoDB
   - Containerized with Docker
   - 3 replicas for high availability

## 🚀 Step-by-Step Deployment

### Step 1: Prepare AWS Environment (5 minutes)

```bash
# Ensure AWS CLI is configured
aws configure

# Verify credentials
aws sts get-caller-identity

# Set your region
export AWS_REGION=us-east-1
```

### Step 2: Deploy Infrastructure (15-20 minutes)

```bash
# Navigate to terraform directory
cd terraform

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars - REQUIRED CHANGES:
# 1. Set unique S3 bucket name
# 2. Verify AWS region
# 3. Update Ubuntu 18.04 AMI for your region
nano terraform.tfvars

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy (will take 15-20 minutes)
terraform apply -auto-approve

# Save outputs for later use
terraform output > ../deployment-info.txt
```

### Step 3: Configure MongoDB VM (5 minutes)

The MongoDB VM is automatically configured via cloud-init, but you need to set up backups:

```bash
# Get MongoDB VM IP from terraform output
MONGODB_IP=$(terraform output -raw mongodb_vm_public_ip)

# SSH into the VM (wait 2-3 minutes for cloud-init to complete)
ssh ubuntu@${MONGODB_IP}

# On the VM, setup backup cron job
cd /home/ubuntu
sudo wget https://raw.githubusercontent.com/your-repo/mongodb-vm/backup-mongodb.sh
sudo wget https://raw.githubusercontent.com/your-repo/mongodb-vm/setup-backup-cron.sh
chmod +x setup-backup-cron.sh
./setup-backup-cron.sh

# Exit VM
exit
```

### Step 4: Build and Push Docker Image (5 minutes)

```bash
# Navigate to app directory
cd ../app

# Build image
docker build -t todo-app:latest .

# Tag for your registry (replace with your registry)
# For AWS ECR:
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.${AWS_REGION}.amazonaws.com

# Create ECR repository
aws ecr create-repository --repository-name todo-app --region ${AWS_REGION}

# Tag and push
docker tag todo-app:latest <ACCOUNT_ID>.dkr.ecr.${AWS_REGION}.amazonaws.com/todo-app:latest
docker push <ACCOUNT_ID>.dkr.ecr.${AWS_REGION}.amazonaws.com/todo-app:latest
```

### Step 5: Deploy to Kubernetes (5 minutes)

```bash
# Configure kubectl
aws eks update-kubeconfig --region ${AWS_REGION} --name wiz-exercise-cluster

# Verify connection
kubectl get nodes

# Update k8s/deployment.yaml with your image URL
cd ../k8s
sed -i '' 's|todo-app:latest|<ACCOUNT_ID>.dkr.ecr.${AWS_REGION}.amazonaws.com/todo-app:latest|g' deployment.yaml

# Update k8s/configmap.yaml with MongoDB IP
MONGODB_IP=$(cd ../terraform && terraform output -raw mongodb_vm_public_ip)
sed -i '' "s|mongodb-vm-service:27017|${MONGODB_IP}:27017|g" configmap.yaml

# Deploy all resources
kubectl apply -f .

# Wait for pods to be ready (2-3 minutes)
kubectl wait --for=condition=ready pod -l app=todo-app -n todo-app --timeout=300s

# Get LoadBalancer URL
kubectl get svc -n todo-app todo-app-loadbalancer
```

### Step 6: Access Application (1 minute)

```bash
# Get the LoadBalancer external IP/hostname
LB_URL=$(kubectl get svc -n todo-app todo-app-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl http://${LB_URL}/health

# Open in browser
echo "Application URL: http://${LB_URL}"
open http://${LB_URL}
```

## ✅ Verification Checklist

- [ ] Terraform applied successfully
- [ ] MongoDB VM is accessible via SSH
- [ ] MongoDB is running and accessible
- [ ] EKS cluster is operational
- [ ] Docker image built and pushed
- [ ] Kubernetes pods are running
- [ ] LoadBalancer has external IP
- [ ] Application is accessible via browser
- [ ] S3 bucket contains backups (after first backup runs)

## 🔍 Quick Verification Commands

```bash
# Check infrastructure
cd terraform
terraform output

# Check MongoDB
ssh ubuntu@$(terraform output -raw mongodb_vm_public_ip) "sudo systemctl status mongod"

# Check Kubernetes
kubectl get all -n todo-app
kubectl logs -n todo-app -l app=todo-app --tail=50

# Check S3 backups
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/

# Test application
curl http://$(kubectl get svc -n todo-app todo-app-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/api/todos
```

## 🐛 Common Issues

### Issue: Terraform fails with "bucket name already exists"
**Solution**: Change `s3_backup_bucket_name` in `terraform.tfvars` to a unique name.

### Issue: MongoDB VM cloud-init not complete
**Solution**: Wait 3-5 minutes after VM creation. Check: `ssh ubuntu@<IP> "tail -f /var/log/cloud-init-output.log"`

### Issue: Pods stuck in ImagePullBackOff
**Solution**: Verify image URL in deployment.yaml matches your registry. Check ECR permissions.

### Issue: LoadBalancer stuck in pending
**Solution**: Check AWS service quotas for ELB. Verify subnet tags for EKS.

### Issue: Cannot connect to MongoDB from pods
**Solution**: Verify security group allows traffic from EKS nodes. Check MongoDB is listening on 0.0.0.0.

## 🧹 Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Destroy infrastructure
cd terraform
terraform destroy -auto-approve

# Delete ECR repository
aws ecr delete-repository --repository-name todo-app --force --region ${AWS_REGION}
```

## ⏱️ Total Deployment Time

- **Infrastructure**: 15-20 minutes
- **Configuration**: 5-10 minutes
- **Application**: 5-10 minutes
- **Total**: ~30-40 minutes

## 📞 Support

For issues or questions:
1. Check the main [README.md](README.md)
2. Review Terraform outputs: `terraform output`
3. Check Kubernetes events: `kubectl get events -n todo-app`
4. Review application logs: `kubectl logs -n todo-app -l app=todo-app`

## 🎓 Learning Objectives

This exercise demonstrates:
- ✅ Infrastructure as Code with Terraform
- ✅ Container orchestration with Kubernetes
- ✅ Cloud security misconfigurations
- ✅ Database backup strategies
- ✅ Network architecture (public/private subnets)
- ✅ IAM and access control issues
- ✅ Data exposure risks

## ⚠️ Remember

This is an **INTENTIONALLY INSECURE** environment for testing purposes. Never use these patterns in production!
