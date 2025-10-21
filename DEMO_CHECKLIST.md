# Live Demo Checklist - Wiz Technical Exercise

## Pre-Demo Setup (Run these BEFORE presentation)

### 1. Deploy Infrastructure
```bash
cd /Users/kalyantatavarti/gitlocal/SecureTest
./scripts/setup-prerequisites.sh
./scripts/deploy-all.sh
```
**Time needed:** 30-40 minutes
**Do this:** 1 hour before presentation

### 2. Verify Everything Works
```bash
# Check EKS
kubectl get nodes
kubectl get all -n todo-app

# Get LoadBalancer URL
LB_URL=$(kubectl get svc -n todo-app todo-app-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://${LB_URL}"

# Test application in browser
open "http://${LB_URL}"
```

### 3. Prepare Terminal Windows

**Terminal 1: AWS Commands**
```bash
cd /Users/kalyantatavarti/gitlocal/SecureTest
# Leave at project root
```

**Terminal 2: Kubernetes Commands**
```bash
cd /Users/kalyantatavarti/gitlocal/SecureTest
# Already configured with kubectl
```

**Terminal 3: Terraform Outputs**
```bash
cd /Users/kalyantatavarti/gitlocal/SecureTest/terraform
terraform output
```

### 4. Open Browser Tabs
- [ ] Application URL (LoadBalancer)
- [ ] GitHub Repository: https://github.com/ktatavar/SecureTest
- [ ] GitHub Actions: https://github.com/ktatavar/SecureTest/actions
- [ ] GitHub Security: https://github.com/ktatavar/SecureTest/security/code-scanning
- [ ] AWS Console (EC2, EKS, S3)

### 5. Prepare Backup Screenshots
Take screenshots of:
- [ ] Running application with todos
- [ ] kubectl get all output
- [ ] GitHub Actions successful run
- [ ] Terraform output
- [ ] wizexercise.txt content

---

## During Presentation - Command Flow

### DEMO 1: Infrastructure Overview (3 min)

```bash
# Terminal 1
aws eks describe-cluster --name wiz-exercise-cluster --region us-east-1 --query 'cluster.{Name:name,Status:status,Version:version}'

aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=wiz-exercise" "Name=instance-state-name,Values=running" \
  --region us-east-1 \
  --query 'Reservations[0].Instances[0].{ID:InstanceId,Type:InstanceType,State:State.Name,IP:PublicIpAddress}'

# Terminal 2
kubectl get nodes
kubectl get all -n todo-app

# Terminal 3
terraform output
```

**Say:** "Here's our complete infrastructure running in AWS..."

---

### DEMO 2: Application Functionality (2 min)

```bash
# Get URL
kubectl get svc -n todo-app todo-app-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Switch to Browser:**
1. Navigate to LoadBalancer URL
2. Create a new todo: "Demonstrate Wiz Exercise"
3. Mark it complete
4. Refresh page
5. Show data persists

**Say:** "This is a fully functional todo application with MongoDB persistence..."

---

### DEMO 3: wizexercise.txt Verification (1 min)

```bash
# Terminal 2
POD=$(kubectl get pods -n todo-app -l app=todo-app -o jsonpath='{.items[0].metadata.name}')
echo "Verifying wizexercise.txt in pod: $POD"

kubectl exec -it $POD -n todo-app -- cat /app/wizexercise.txt
```

**Expected output:** `Kalyan Tatavarti`

**Say:** "As required, the container includes wizexercise.txt with my name..."

---

### DEMO 4: Cluster-Admin Vulnerability (2 min)

```bash
# Terminal 2
kubectl get clusterrolebinding todo-app-admin-binding -o yaml | grep -A5 "roleRef:"

kubectl get clusterrolebinding todo-app-admin-binding -o jsonpath='{.roleRef.name}'

# Show what this means
kubectl exec -it $POD -n todo-app -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/
```

**Say:** "This is critically insecure - the pods have cluster-admin privileges. Let me show you what that means..."

**Explain:** "With this role, if an attacker compromises the application, they can access every secret in every namespace, create new resources, and effectively own the entire cluster."

---

### DEMO 5: Public S3 Bucket (2 min)

```bash
# Terminal 3
S3_BUCKET=$(terraform output -raw mongodb_backup_bucket)
echo "S3 Bucket: $S3_BUCKET"

# List backups
aws s3 ls s3://${S3_BUCKET}/

# Show public access
LATEST_BACKUP=$(aws s3 ls s3://${S3_BUCKET}/ | tail -1 | awk '{print $4}')
echo "Public URL: https://${S3_BUCKET}.s3.amazonaws.com/${LATEST_BACKUP}"

# Test public access (no credentials needed!)
curl -I "https://${S3_BUCKET}.s3.amazonaws.com/${LATEST_BACKUP}"
```

**Say:** "Notice I can access this backup without AWS credentials - it's completely public..."

---

### DEMO 6: Network Exposure (1 min)

```bash
# Terminal 1
MONGODB_IP=$(cd terraform && terraform output -raw mongodb_vm_public_ip)
echo "MongoDB IP: $MONGODB_IP"

# Show SSH is open
nc -zv $MONGODB_IP 22

# Show MongoDB is open
nc -zv $MONGODB_IP 27017

# Show security group
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*mongodb*" \
  --region us-east-1 \
  --query 'SecurityGroups[0].IpPermissions[*].{Port:FromPort,CIDR:IpRanges[0].CidrIp}'
```

**Say:** "Both SSH and MongoDB are exposed to the entire internet - 0.0.0.0/0..."

---

### DEMO 7: Outdated Software (1 min)

```bash
# Terminal 1
# SSH to MongoDB VM
ssh ubuntu@$MONGODB_IP

# Once connected:
lsb_release -a
# Shows: Ubuntu 18.04.6 LTS (EOL April 2023)

mongod --version
# Shows: MongoDB 4.0.28 (released 2021)

exit
```

**Say:** "Both the OS and database are severely outdated with known vulnerabilities..."

---

### DEMO 8: Security Scanning (2 min)

**Switch to Browser:**
1. Navigate to GitHub Actions tab
2. Click on latest "Build and Push Docker Image" run
3. Show Trivy scan step
4. Navigate to Security → Code Scanning
5. Show findings

**Say:** "Our CI/CD pipeline automatically scans for security issues, but these are intentional..."

---

### DEMO 9: Comprehensive Verification (1 min)

```bash
# Terminal 1
./scripts/verify-security-issues.sh
```

**Say:** "I created an automated script that verifies all 12+ vulnerabilities are present..."

**Let it run and show the checklist**

---

### DEMO 10: GitHub Repository (1 min)

**Switch to Browser:**
1. Show README.md
2. Show directory structure
3. Show automation scripts in `/scripts`
4. Show Terraform code
5. Show Kubernetes manifests

**Say:** "All code is in GitHub with comprehensive documentation and automation..."

---

## Post-Demo Q&A Preparation

### Expected Questions & Answers

**Q: How would you fix the cluster-admin issue?**
```bash
# Show the solution
cat k8s/clusterrolebinding.yaml

# Explain: "I would create a limited Role instead of using cluster-admin:
# - Only allow access to the todo-app namespace
# - Only allow read/write to ConfigMaps and Secrets needed
# - No cluster-wide permissions"
```

**Q: What's the attack path from internet to data?**
**A:** Draw on screen:
```
Internet → SSH (0.0.0.0/0) → Weak Password
  → Root Access → Overpermissive IAM → Create EC2
  → Escalate to Admin → Full AWS Access

OR

Internet → MongoDB (0.0.0.0/0:27017) → Weak Auth
  → Database Access → Exfiltrate Data
```

**Q: How long did this take?**
**A:** "About 14 hours total:
- 2 hours planning
- 4 hours infrastructure
- 3 hours application
- 3 hours DevSecOps
- 2 hours documentation"

**Q: How would Wiz detect these?**
**A:** "Wiz would automatically:
1. Discover all assets (VMs, containers, K8s)
2. Scan for CVEs (outdated software)
3. Map network topology (exposed ports)
4. Analyze IAM policies (overpermissive roles)
5. Check RBAC (cluster-admin)
6. Scan for secrets (weak passwords)
7. Show attack paths from internet to data
8. Prioritize by risk score"

**Q: What was the hardest part?**
**A:** "Network dependency cleanup during teardown. EKS and VPC deletion can take 20-30 minutes due to ENIs, NAT gateways, and EIPs. I built automated cleanup scripts to handle this."

**Q: Why these specific vulnerabilities?**
**A:** "These are common real-world misconfigurations I've seen:
- Shadow IT with outdated software
- Dev environments exposed to internet
- Over-permissioned roles for 'convenience'
- Public S3 buckets from misconfiguration
- Weak passwords in test environments"

---

## Emergency Backup Plans

### If Application is Down:
- Show screenshots of working application
- Explain the architecture from code
- Show the Docker container locally

### If Kubernetes is Unavailable:
- Use terraform output to show infrastructure
- Show AWS Console
- Explain from code and architecture diagram

### If GitHub is Down:
- Show local repository
- Display code in terminal
- Run workflows locally

### If Live Demo Fails Completely:
- Use screenshots for everything
- Walk through code instead
- "Let me show you the code that creates this vulnerability..."

---

## Time Management

| Section | Allocated | Actual |
|---------|-----------|--------|
| Intro | 3 min | |
| Architecture | 5 min | |
| Live Demo | 8 min | |
| Security Deep Dive | 10 min | |
| DevSecOps | 5 min | |
| Challenges | 4 min | |
| Wiz Value | 3 min | |
| Final Demo | 5 min | |
| Buffer | 2 min | |
| **Total** | **45 min** | |
| Q&A | 15 min | |

**Pacing:**
- If ahead: Expand on Wiz value proposition
- If behind: Shorten deep dive, keep demos

---

## Final Pre-Flight Check (5 minutes before)

- [ ] All infrastructure deployed and accessible
- [ ] Application loads in browser
- [ ] All terminals positioned and ready
- [ ] Browser tabs open
- [ ] Backup screenshots accessible
- [ ] Water/beverage nearby
- [ ] Phone on silent
- [ ] Notifications muted
- [ ] Screen sharing tested
- [ ] Internet connection stable

**Take a deep breath. You've got this! 🚀**

---

## Post-Presentation Cleanup

```bash
# After presentation is complete
./scripts/cleanup-all.sh --fast --force

# This will:
# - Delete Kubernetes namespace
# - Destroy EKS cluster (10-15 min with --fast)
# - Remove MongoDB VM
# - Delete VPC and networking
# - Clean up S3 bucket
```

**Total cleanup time with --fast:** 10-15 minutes

---

## Presentation Success Metrics

**You'll know you did well if:**
- ✅ Demonstrated all key vulnerabilities
- ✅ Showed working infrastructure live
- ✅ Explained Wiz value clearly
- ✅ Handled questions confidently
- ✅ Stayed within time limit
- ✅ Made it conversational, not just a lecture

**Remember:**
- It's okay if something doesn't work - explain what you'd do
- The panelists want to see your thought process
- They're evaluating communication, not just technical skills
- Be honest about trade-offs and decisions

Good luck! 🎉
