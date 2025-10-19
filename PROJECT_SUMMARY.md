# Wiz Technical Exercise v4 - Project Summary

## 📦 Complete Implementation

This repository contains a **complete implementation** of the Wiz Technical Exercise v4 requirements, featuring an intentionally insecure web application environment for security testing.

## 📁 Project Structure

```
SecureTest/
├── app/                              # Web Application
│   ├── server.js                     # Express.js backend (API + routes)
│   ├── public/
│   │   └── index.html               # Beautiful modern UI (todo list)
│   ├── package.json                 # Node.js dependencies
│   ├── Dockerfile                   # Container image definition
│   └── .dockerignore                # Docker build exclusions
│
├── k8s/                              # Kubernetes Manifests
│   ├── namespace.yaml               # todo-app namespace
│   ├── configmap.yaml               # MongoDB connection config
│   ├── secret.yaml                  # Database credentials
│   ├── deployment.yaml              # App deployment (3 replicas)
│   ├── service.yaml                 # Internal ClusterIP service
│   ├── loadbalancer.yaml            # Public LoadBalancer
│   └── network-policy.yaml          # Network security policies
│
├── mongodb-vm/                       # MongoDB VM Configuration
│   ├── setup-mongodb.sh             # MongoDB 4.4.18 installation
│   ├── cloud-init.yaml              # Ubuntu 18.04 VM initialization
│   ├── backup-mongodb.sh            # Daily backup to S3 script
│   └── setup-backup-cron.sh         # Cron job configuration
│
├── terraform/                        # Infrastructure as Code
│   ├── main.tf                      # Complete AWS infrastructure
│   ├── variables.tf                 # Input variables
│   ├── outputs.tf                   # Output values & summary
│   └── terraform.tfvars.example     # Configuration template
│
├── README.md                         # Complete documentation
├── DEPLOYMENT_GUIDE.md              # Step-by-step deployment
├── PROJECT_SUMMARY.md               # This file
└── .gitignore                       # Git exclusions
```

## ✅ Requirements Fulfilled

### 1. ✅ Virtual Machine with MongoDB Database Server

**Implemented:**
- Ubuntu 18.04 LTS (OUTDATED - EOL April 2023)
- MongoDB 4.4.18 (OUTDATED - 1+ years old)
- SSH exposed to public internet (0.0.0.0/0)
- MongoDB exposed to public internet (0.0.0.0/0)
- Overly permissive IAM role (can create VMs, security groups, IAM roles)
- Kubernetes-restricted access with authentication
- Daily automated backups to S3

**Files:**
- `mongodb-vm/setup-mongodb.sh` - Installation script
- `mongodb-vm/cloud-init.yaml` - VM initialization
- `terraform/main.tf` - VM infrastructure (aws_instance.mongodb_vm)

### 2. ✅ Database Backups to Cloud Storage

**Implemented:**
- Daily automated backups (2 AM cron job)
- S3 bucket with public read access (INSECURE)
- S3 bucket with public listing enabled (INSECURE)
- Compressed backup archives (.tar.gz)
- 7-day retention policy

**Files:**
- `mongodb-vm/backup-mongodb.sh` - Backup script
- `mongodb-vm/setup-backup-cron.sh` - Cron setup
- `terraform/main.tf` - S3 bucket (aws_s3_bucket.mongodb_backups)

### 3. ✅ Containerized Web Application

**Implemented:**
- Node.js + Express + MongoDB todo list app
- Beautiful modern UI with gradient design
- RESTful API (GET, POST, PUT, DELETE)
- Docker container with health checks
- Multi-stage optimized build

**Files:**
- `app/server.js` - Backend application
- `app/public/index.html` - Frontend UI
- `app/package.json` - Dependencies
- `app/Dockerfile` - Container definition

### 4. ✅ Kubernetes Deployment

**Implemented:**
- EKS cluster with private subnet deployment
- 3 replicas for high availability
- LoadBalancer for public internet access
- Network policies for security
- ConfigMaps and Secrets for configuration
- Health checks (liveness & readiness probes)
- Resource limits and requests

**Files:**
- `k8s/namespace.yaml` - Namespace
- `k8s/deployment.yaml` - Application deployment
- `k8s/service.yaml` - Internal service
- `k8s/loadbalancer.yaml` - Public access
- `k8s/configmap.yaml` - Configuration
- `k8s/secret.yaml` - Credentials
- `k8s/network-policy.yaml` - Network rules

### 5. ✅ Complete Infrastructure

**Implemented:**
- VPC with public and private subnets
- Internet Gateway and NAT Gateway
- Security groups (intentionally insecure)
- IAM roles and policies (overly permissive)
- EKS cluster with managed node groups
- Load balancer integration
- Complete networking setup

**Files:**
- `terraform/main.tf` - All infrastructure
- `terraform/variables.tf` - Configuration
- `terraform/outputs.tf` - Deployment info

## 🔒 Security Issues (By Design)

### Critical Issues
1. ❌ **Outdated OS**: Ubuntu 18.04 (EOL April 2023)
2. ❌ **Outdated Database**: MongoDB 4.4.18 (1+ years old)
3. ❌ **SSH Exposed**: Port 22 open to 0.0.0.0/0
4. ❌ **MongoDB Exposed**: Port 27017 open to 0.0.0.0/0
5. ❌ **Public Backups**: S3 bucket with public read + listing
6. ❌ **Overly Permissive IAM**: Can create VMs, SGs, IAM roles
7. ❌ **Weak Passwords**: admin123, changeme123
8. ❌ **No Encryption**: No TLS/SSL for MongoDB
9. ❌ **Password Auth**: SSH password authentication enabled
10. ❌ **No MFA**: No multi-factor authentication

## 🚀 Deployment Options

### Option 1: Quick Deploy (Recommended)
Follow the [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for step-by-step instructions.

### Option 2: Manual Deploy
Follow the [README.md](README.md) for detailed explanations.

### Time Estimate
- **Infrastructure**: 15-20 minutes
- **Configuration**: 5-10 minutes
- **Application**: 5-10 minutes
- **Total**: ~30-40 minutes

## 🎯 Key Features

### Application Features
- ✅ Create, read, update, delete todos
- ✅ Mark todos as complete/incomplete
- ✅ Beautiful gradient UI design
- ✅ Responsive design
- ✅ Real-time updates
- ✅ RESTful API
- ✅ Health check endpoint

### Infrastructure Features
- ✅ Fully automated deployment
- ✅ Infrastructure as Code (Terraform)
- ✅ Container orchestration (Kubernetes)
- ✅ Auto-scaling capabilities
- ✅ High availability (3 replicas)
- ✅ Load balancing
- ✅ Network policies
- ✅ Automated backups

### Security Testing Features
- ✅ Multiple vulnerability types
- ✅ Realistic misconfigurations
- ✅ Public exposure scenarios
- ✅ IAM permission issues
- ✅ Data exposure risks
- ✅ Outdated software versions

## 📊 Technology Stack

### Application
- **Backend**: Node.js 18, Express.js
- **Database**: MongoDB 4.4.18
- **Frontend**: Vanilla JavaScript, HTML5, CSS3
- **Container**: Docker

### Infrastructure
- **Cloud**: AWS (VPC, EC2, EKS, S3, IAM)
- **IaC**: Terraform
- **Orchestration**: Kubernetes (EKS)
- **Networking**: VPC, Subnets, NAT, IGW, Load Balancer

### DevOps
- **CI/CD Ready**: Dockerfile, K8s manifests
- **Monitoring**: Health checks, readiness probes
- **Backup**: Automated daily backups
- **Logging**: Application and system logs

## 📝 Documentation

1. **README.md** - Complete project documentation
   - Architecture overview
   - Security vulnerabilities
   - Setup instructions
   - Troubleshooting guide

2. **DEPLOYMENT_GUIDE.md** - Quick deployment steps
   - Step-by-step instructions
   - Verification checklist
   - Common issues and solutions

3. **PROJECT_SUMMARY.md** - This file
   - Project overview
   - Requirements fulfillment
   - File structure

## 🧪 Testing

### Functional Testing
```bash
# Test application
curl http://<LOAD_BALANCER_URL>/health
curl http://<LOAD_BALANCER_URL>/api/todos

# Test MongoDB
mongosh "mongodb://todouser:changeme123@<MONGODB_IP>:27017/todoapp"

# Test backups
aws s3 ls s3://<BUCKET_NAME>/
```

### Security Testing
```bash
# Test SSH exposure
nmap -p 22 <MONGODB_IP>

# Test MongoDB exposure
nmap -p 27017 <MONGODB_IP>

# Test public S3 bucket
curl https://<BUCKET_NAME>.s3.amazonaws.com/

# Test IAM permissions
aws sts get-caller-identity
```

## 🎓 Learning Outcomes

This project demonstrates:
1. **Infrastructure as Code** - Terraform for AWS
2. **Container Orchestration** - Kubernetes/EKS
3. **Cloud Security** - Misconfigurations and vulnerabilities
4. **Database Management** - MongoDB setup and backups
5. **Network Architecture** - VPC, subnets, security groups
6. **IAM & Access Control** - Roles, policies, permissions
7. **DevOps Practices** - CI/CD ready, automated deployments
8. **Full-Stack Development** - Node.js, Express, MongoDB

## 🔧 Customization

### Change Cloud Provider
The architecture can be adapted for:
- **GCP**: GKE, Cloud SQL, Cloud Storage
- **Azure**: AKS, Azure Database, Blob Storage

### Change Application
Replace the todo app with any Node.js application:
1. Update `app/server.js`
2. Rebuild Docker image
3. Redeploy to Kubernetes

### Change Database
Replace MongoDB with:
- PostgreSQL
- MySQL
- DynamoDB
- Any other database

## 🎯 Exercise Objectives Met

| Requirement | Status | Implementation |
|------------|--------|----------------|
| Outdated Linux VM | ✅ | Ubuntu 18.04 LTS |
| Outdated MongoDB | ✅ | MongoDB 4.4.18 |
| SSH Exposed | ✅ | 0.0.0.0/0 access |
| Overly Permissive IAM | ✅ | Can create VMs/SGs/Roles |
| K8s Restricted DB Access | ✅ | Authentication required |
| Daily Backups | ✅ | Cron job at 2 AM |
| Public S3 Bucket | ✅ | Public read + listing |
| Containerized App | ✅ | Docker + Dockerfile |
| K8s Private Subnet | ✅ | EKS private node group |
| Public Load Balancer | ✅ | AWS ELB |

## 🏆 Highlights

- **Complete Implementation**: All requirements fulfilled
- **Production-Quality Code**: Clean, documented, maintainable
- **Best Practices**: IaC, containerization, orchestration
- **Comprehensive Docs**: README, guides, comments
- **Security Focus**: Multiple vulnerability types
- **Easy Deployment**: Automated with Terraform
- **Realistic Scenario**: Mirrors real-world misconfigurations

## ⚠️ Important Notes

1. **This is intentionally insecure** - Never use in production
2. **For testing only** - Educational and security testing purposes
3. **Clean up resources** - Run `terraform destroy` when done
4. **Monitor costs** - AWS resources incur charges
5. **Use test data only** - No real or sensitive information

## 📞 Next Steps

1. **Deploy**: Follow [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
2. **Test**: Verify all components are working
3. **Explore**: Test the security vulnerabilities
4. **Learn**: Understand the misconfigurations
5. **Clean Up**: Destroy resources when done

## 🎉 Success Criteria

- [ ] Infrastructure deployed successfully
- [ ] Application accessible via LoadBalancer
- [ ] MongoDB accessible and functioning
- [ ] Backups running and stored in S3
- [ ] All security issues present and testable
- [ ] Documentation clear and complete

---

**Project Status**: ✅ Complete and Ready for Deployment

**Estimated Deployment Time**: 30-40 minutes

**Difficulty Level**: Intermediate

**Prerequisites**: AWS account, Terraform, kubectl, Docker

---

*Created for Wiz Technical Exercise v4*
