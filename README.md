# Wiz Technical Exercise - Insecure WebApp Environment

This repository contains an **intentionally insecure** infrastructure setup for the Wiz Technical Exercise v4. The environment demonstrates various security vulnerabilities and misconfigurations for testing and educational purposes.

## 🚀 Quick Start

**Want to deploy quickly?** Use our automated setup:

```bash
# 1. Automated setup and configuration
./scripts/setup-prerequisites.sh

# 2. Complete deployment (infrastructure + application)
./scripts/deploy-all.sh

# 3. Verify security vulnerabilities
./scripts/verify-security-issues.sh
```

**Estimated deployment time:** 25-40 minutes

### 📚 Documentation

- **[COMPLETE_GUIDE.md](COMPLETE_GUIDE.md)** - 🆕 **Comprehensive guide with everything you need**
- **[QUICKSTART.md](QUICKSTART.md)** - Fast deployment guide with automation
- **[REQUIREMENTS_CHECKLIST.md](REQUIREMENTS_CHECKLIST.md)** - Complete requirements verification
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Detailed step-by-step instructions
- **[GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)** - CI/CD pipeline configuration
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Implementation summary

### 🛠️ Helper Scripts

All scripts are in the `/scripts` directory:
- `setup-prerequisites.sh` - Auto-configure AWS and Terraform
- `deploy-all.sh` - Complete automated deployment
- `verify-security-issues.sh` - Verify all 12+ vulnerabilities
- `cleanup-all.sh` - Remove all resources
- `switch-aws-account.sh` - Switch between AWS accounts/profiles

## ⚠️ WARNING

**This infrastructure is INTENTIONALLY INSECURE and should NEVER be used in production!**

Security issues include:
- Outdated software versions (OS and MongoDB)
- Publicly exposed services (SSH, MongoDB)
- Overly permissive IAM roles
- Public cloud storage with listing enabled
- Weak passwords and authentication
- No encryption at rest or in transit

## Architecture Overview

```
Internet
    ↓
Load Balancer (Public)
    ↓
Kubernetes Cluster
    ├── Public Subnet (Load Balancer)
    └── Private Subnet (Application Pods)
            ↓
    MongoDB VM (Public IP)
    ├── Ubuntu 18.04 (OUTDATED)
    ├── MongoDB 4.4.18 (OUTDATED)
    ├── SSH Exposed (0.0.0.0/0)
    └── Overly Permissive IAM Role
            ↓
    S3 Bucket (Public Read + Listing)
    └── Daily MongoDB Backups
```

## Components

### 1. Web Application
- **Technology**: Node.js + Express + MongoDB
- **Features**: Simple todo list application
- **Container**: Docker image with health checks
- **Deployment**: Kubernetes with 3 replicas

### 2. MongoDB Database VM
- **OS**: Ubuntu 18.04 LTS (OUTDATED - EOL April 2023)
- **Database**: MongoDB 4.4.18 (OUTDATED)
- **Exposure**: SSH (port 22) and MongoDB (port 27017) exposed to internet
- **IAM**: Overly permissive role (can create VMs, security groups, IAM roles)
- **Authentication**: Weak passwords, Kubernetes-restricted access

### 3. Backup System
- **Frequency**: Daily automated backups (2 AM)
- **Storage**: AWS S3 bucket
- **Security Issues**: 
  - Public read access enabled
  - Public listing enabled
  - Backups contain sensitive data

### 4. Kubernetes Cluster
- **Platform**: AWS EKS
- **Network**: Private subnet deployment
- **Exposure**: Public load balancer
- **Features**: Network policies, health checks, auto-scaling

## Prerequisites

- AWS Account with appropriate credentials
- Terraform >= 1.0
- kubectl
- Docker
- AWS CLI configured
- Node.js 18+ (for local development)

## Quick Start

### 1. Deploy Infrastructure

```bash
# Navigate to terraform directory
cd terraform

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy infrastructure
terraform apply

# Save outputs
terraform output > ../deployment-info.txt
```

### 2. Configure MongoDB VM

```bash
# SSH into MongoDB VM (IP from terraform output)
ssh ubuntu@<MONGODB_VM_IP>

# The cloud-init script will automatically:
# - Install MongoDB 4.4.18
# - Configure insecure settings
# - Create database users
# - Setup firewall rules

# Verify MongoDB is running
sudo systemctl status mongod

# Setup backup cron job
cd /home/ubuntu
chmod +x setup-backup-cron.sh
./setup-backup-cron.sh
```

### 3. Build and Push Docker Image

```bash
# Navigate to app directory
cd app

# Build Docker image
docker build -t todo-app:latest .

# Tag for your registry (replace with your registry)
docker tag todo-app:latest <YOUR_REGISTRY>/todo-app:latest

# Push to registry
docker push <YOUR_REGISTRY>/todo-app:latest
```

### 4. Deploy to Kubernetes

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name wiz-exercise-cluster

# Update k8s/deployment.yaml with your image
# Edit line: image: todo-app:latest
# Replace with: image: <YOUR_REGISTRY>/todo-app:latest

# Update k8s/configmap.yaml with MongoDB VM IP
# Edit MONGODB_URI: "mongodb://<MONGODB_VM_IP>:27017/todoapp"

# Deploy all resources
kubectl apply -f k8s/

# Verify deployment
kubectl get all -n todo-app

# Get LoadBalancer URL
kubectl get svc -n todo-app todo-app-loadbalancer

# Wait for LoadBalancer to provision (may take 2-3 minutes)
# Access the application at the EXTERNAL-IP
```

### 5. Verify Everything Works

```bash
# Check application pods
kubectl get pods -n todo-app

# Check application logs
kubectl logs -n todo-app -l app=todo-app

# Test the application
curl http://<LOAD_BALANCER_URL>/health

# Access web interface
open http://<LOAD_BALANCER_URL>
```

## Project Structure

```
.
├── app/                          # Web application
│   ├── server.js                 # Express server
│   ├── public/
│   │   └── index.html           # Frontend
│   ├── package.json             # Dependencies
│   ├── Dockerfile               # Container image
│   └── .dockerignore
│
├── k8s/                          # Kubernetes manifests
│   ├── namespace.yaml           # Namespace definition
│   ├── configmap.yaml           # Configuration
│   ├── secret.yaml              # Credentials (weak)
│   ├── deployment.yaml          # Application deployment
│   ├── service.yaml             # Internal service
│   ├── loadbalancer.yaml        # Public load balancer
│   └── network-policy.yaml      # Network policies
│
├── mongodb-vm/                   # MongoDB VM setup
│   ├── setup-mongodb.sh         # MongoDB installation script
│   ├── cloud-init.yaml          # VM initialization
│   ├── backup-mongodb.sh        # Backup script
│   └── setup-backup-cron.sh     # Cron job setup
│
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                  # Main infrastructure
│   ├── variables.tf             # Variable definitions
│   ├── outputs.tf               # Output values
│   └── terraform.tfvars.example # Example configuration
│
└── README.md                     # This file
```

## Security Vulnerabilities (By Design)

### 1. Outdated Software
- ❌ Ubuntu 18.04 LTS (EOL April 2023)
- ❌ MongoDB 4.4.18 (1+ years outdated)

### 2. Network Exposure
- ❌ SSH exposed to 0.0.0.0/0 (port 22)
- ❌ MongoDB exposed to 0.0.0.0/0 (port 27017)
- ❌ No VPN or bastion host

### 3. IAM & Permissions
- ❌ Overly permissive IAM role
- ❌ Can create EC2 instances
- ❌ Can create security groups
- ❌ Can create and attach IAM roles

### 4. Data Storage
- ❌ S3 bucket with public read access
- ❌ S3 bucket with public listing enabled
- ❌ Backups contain sensitive data
- ❌ No encryption at rest

### 5. Authentication
- ❌ Weak passwords (admin123, changeme123)
- ❌ Password authentication enabled for SSH
- ❌ No MFA
- ❌ No certificate-based authentication

### 6. Database Security
- ❌ MongoDB accessible from internet
- ❌ No TLS/SSL encryption
- ❌ Weak authentication
- ❌ No audit logging

## Testing the Vulnerabilities

### Test 1: SSH Access
```bash
# SSH should be accessible from anywhere
ssh ubuntu@<MONGODB_VM_IP>
```

### Test 2: MongoDB Access
```bash
# MongoDB should be accessible from anywhere
mongosh "mongodb://todouser:changeme123@<MONGODB_VM_IP>:27017/todoapp"
```

### Test 3: Public S3 Bucket
```bash
# List bucket contents (should work without authentication)
curl https://<BUCKET_NAME>.s3.amazonaws.com/

# Download a backup (should work without authentication)
curl https://<BUCKET_NAME>.s3.amazonaws.com/<BACKUP_FILE>.tar.gz -o backup.tar.gz
```

### Test 4: Overly Permissive IAM
```bash
# SSH into MongoDB VM
ssh ubuntu@<MONGODB_VM_IP>

# Try to create a new EC2 instance (should work)
aws ec2 run-instances --image-id ami-xxxxx --instance-type t2.micro
```

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Destroy infrastructure
cd terraform
terraform destroy

# Confirm with 'yes'
```

## Environment Variables

### Application
- `PORT`: Application port (default: 3000)
- `MONGODB_URI`: MongoDB connection string

### Backup Script
- `S3_BUCKET`: S3 bucket name for backups
- `S3_REGION`: AWS region
- `MONGODB_URI`: MongoDB connection string

## Troubleshooting

### MongoDB Connection Issues
```bash
# Check MongoDB status
sudo systemctl status mongod

# Check MongoDB logs
sudo tail -f /var/log/mongodb/mongod.log

# Test connection locally
mongosh "mongodb://localhost:27017/todoapp"
```

### Kubernetes Pod Issues
```bash
# Check pod status
kubectl get pods -n todo-app

# Check pod logs
kubectl logs -n todo-app <POD_NAME>

# Describe pod
kubectl describe pod -n todo-app <POD_NAME>
```

### LoadBalancer Not Working
```bash
# Check service
kubectl get svc -n todo-app

# Check events
kubectl get events -n todo-app

# Verify security groups allow traffic
```

## Additional Resources

- [Wiz Security Platform](https://www.wiz.io/)
- [MongoDB Security Checklist](https://docs.mongodb.com/manual/administration/security-checklist/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)

## License

This project is for educational purposes only. Use at your own risk.

## Disclaimer

This infrastructure is intentionally insecure and designed for security testing and educational purposes only. Never deploy this in a production environment or with real data. The authors are not responsible for any misuse or damage caused by this code.
