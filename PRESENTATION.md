# Wiz Technical Exercise v4 - Presentation
## Intentionally Insecure Cloud Infrastructure

**Presented by:** Kalyan Tatavarti
**Date:** [Your Presentation Date]
**Duration:** 45 minutes (30 min presentation + 15 min Q&A)

---

## Presentation Agenda

1. **Introduction & Overview** (3 min)
2. **Architecture & Approach** (5 min)
3. **Live Infrastructure Demonstration** (8 min)
4. **Security Vulnerabilities Deep Dive** (10 min)
5. **DevSecOps & CI/CD** (5 min)
6. **Challenges & Solutions** (4 min)
7. **How Wiz Would Help** (3 min)
8. **Live Security Demonstration** (5 min)
9. **Q&A** (15 min)

---

## SLIDE 1: Title Slide

```
Wiz Technical Exercise v4
Intentionally Insecure Cloud Infrastructure

By: Kalyan Tatavarti
Date: [Date]
```

**Speaker Notes:**
- Introduce yourself
- Brief background (30 seconds)
- "Today I'll demonstrate an intentionally insecure cloud infrastructure I built for this exercise"
- "We'll explore 12+ security vulnerabilities and how Wiz could help detect them"

---

## SLIDE 2: Executive Summary

**What We'll Cover:**
- ✅ Complete AWS infrastructure deployment
- ✅ 2-tier web application (Kubernetes + MongoDB)
- ✅ 12+ intentional security misconfigurations
- ✅ Full DevSecOps pipeline with security scanning
- ✅ Live demonstration of vulnerabilities
- ✅ How Wiz provides value

**By the Numbers:**
- 1 VPC with public/private subnets
- 1 EKS Kubernetes cluster
- 1 MongoDB EC2 instance (Ubuntu 18.04)
- 3 application pods
- 12+ critical security issues

---

## SLIDE 3: Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                   Internet                       │
└───────────────────┬─────────────────────────────┘
                    │
            ┌───────▼────────┐
            │  Load Balancer │ (Public)
            │   Port 80      │
            └───────┬────────┘
                    │
    ┌───────────────▼──────────────────┐
    │         EKS Cluster              │
    │  ┌──────────────────────────┐   │
    │  │  Todo App (3 replicas)   │   │
    │  │  • Cluster-Admin Role    │   │
    │  │  • wizexercise.txt       │   │
    │  └──────────┬───────────────┘   │
    │             │                    │
    └─────────────┼────────────────────┘
                  │
    ┌─────────────▼─────────────┐
    │   MongoDB VM (EC2)        │
    │   • Ubuntu 18.04 (EOL)    │
    │   • MongoDB 4.0.28        │
    │   • SSH: 0.0.0.0/0        │
    │   • Overpermissive IAM    │
    └─────────────┬─────────────┘
                  │
    ┌─────────────▼─────────────┐
    │   S3 Bucket               │
    │   • Public Read           │
    │   • Public Listing        │
    │   • Daily Backups         │
    └───────────────────────────┘
```

**Speaker Notes:**
- "This is a classic 2-tier architecture with intentional security gaps"
- "Public internet → Load Balancer → Kubernetes → MongoDB → S3"
- "Every layer has deliberate vulnerabilities we'll explore"

---

## SLIDE 4: Technology Stack

**Infrastructure:**
- ☁️ **Cloud Provider:** AWS
- 🏗️ **IaC:** Terraform (387 lines)
- ⚓ **Orchestration:** Amazon EKS (Kubernetes 1.28)
- 💾 **Database:** MongoDB 4.0.28 on Ubuntu 18.04
- 📦 **Storage:** Amazon S3

**Application:**
- 🐳 **Container:** Docker (Alpine Linux)
- 🔧 **Backend:** Node.js + Express
- 🎨 **Frontend:** HTML5 + JavaScript
- 💽 **ORM:** Mongoose

**CI/CD & Security:**
- 🔄 **VCS:** GitHub
- 🤖 **CI/CD:** GitHub Actions
- 🔍 **Security Scanning:** Trivy, tfsec, Checkov
- 📊 **Registry:** Amazon ECR

---

## SLIDE 5: My Approach to the Build-Out

**Phase 1: Planning & Design** (2 hours)
- Reviewed requirements document thoroughly
- Designed architecture to meet all criteria
- Identified 12+ vulnerability types to implement
- Created implementation checklist

**Phase 2: Infrastructure** (4 hours)
- Built VPC with public/private subnets
- Deployed EKS cluster with managed node groups
- Created MongoDB EC2 with cloud-init automation
- Configured intentionally weak security groups

**Phase 3: Application** (3 hours)
- Built Node.js todo app with MongoDB integration
- Created Docker container with wizexercise.txt
- Deployed to Kubernetes with cluster-admin role
- Configured LoadBalancer exposure

**Phase 4: DevSecOps** (3 hours)
- Set up GitHub Actions for CI/CD
- Integrated security scanning (Trivy, tfsec, Checkov)
- Created automated deployment scripts
- Built verification and cleanup tools

**Phase 5: Documentation** (2 hours)
- Comprehensive README and guides
- Requirements checklist
- Troubleshooting documentation

**Total Time:** ~14 hours

---

## SLIDE 6: Key Challenges & Adaptations

### Challenge 1: MongoDB Version Compatibility
**Problem:** Ubuntu 18.04 + MongoDB compatibility issues
**Solution:** Used cloud-init to install specific MongoDB 4.0.28 version with custom repository configuration

### Challenge 2: EKS Cluster Cleanup Time
**Problem:** Node groups take 20-30 minutes to destroy
**Solution:** Created fast cleanup mode (`--fast`) that skips graceful shutdown, reducing time to 10-15 minutes

### Challenge 3: Network Dependencies on Teardown
**Problem:** VPC deletion fails due to orphaned ENIs and EIPs
**Solution:** Built automated cleanup script that removes all network dependencies before retry

### Challenge 4: GitHub Actions on Feature Branches
**Problem:** Workflows only triggered on main/master branches
**Solution:** Updated workflows to include `claude/**` pattern for development branches

### Challenge 5: Docker Tag Validation
**Problem:** Branch names with slashes created invalid Docker tags
**Solution:** Changed tagging strategy to use SHA-based tags instead of branch names

---

## SLIDE 7: 🎬 LIVE DEMO - Part 1: Infrastructure

**Switch to Terminal**

### Verification Steps:

```bash
# 1. Show AWS Resources
aws eks describe-cluster --name wiz-exercise-cluster --region us-east-1 --query 'cluster.status'
aws ec2 describe-instances --filters "Name=tag:Project,Values=wiz-exercise" --region us-east-1

# 2. Show Kubernetes Resources
kubectl get all -n todo-app
kubectl get nodes

# 3. Show LoadBalancer URL
kubectl get svc -n todo-app todo-app-loadbalancer
```

### Open Browser - Show Application
- Navigate to LoadBalancer URL
- Create a todo item
- Refresh page to show persistence
- Demonstrate MongoDB connection

**Speaker Notes:**
- "Here's the fully deployed infrastructure"
- "EKS cluster is running with 2-4 nodes"
- "Application is accessible via public LoadBalancer"
- "Data persists in MongoDB - let me show you"

---

## SLIDE 8: 🎬 LIVE DEMO - Part 2: Container Verification

**Switch to Terminal**

```bash
# 1. Verify wizexercise.txt in running container
POD=$(kubectl get pods -n todo-app -l app=todo-app -o jsonpath='{.items[0].metadata.name}')
echo "Pod name: $POD"

kubectl exec -it $POD -n todo-app -- cat /app/wizexercise.txt
# Should show: Kalyan Tatavarti

# 2. Verify cluster-admin role
kubectl get clusterrolebinding todo-app-admin-binding -o yaml
kubectl get serviceaccount todo-app-admin -n todo-app

# 3. Show inside container
kubectl exec -it $POD -n todo-app -- ls -la /app/
```

**Speaker Notes:**
- "This demonstrates the wizexercise.txt file is embedded in the container"
- "Notice the pod has cluster-admin privileges - this is critically insecure"
- "The application can access the entire Kubernetes API with full admin rights"

---

## SLIDE 9: Security Vulnerabilities - Overview

**12+ Intentional Misconfigurations Implemented:**

| Category | Count | Severity |
|----------|-------|----------|
| Outdated Software | 2 | HIGH |
| Network Exposure | 2 | CRITICAL |
| Authentication | 2 | HIGH |
| Authorization | 2 | CRITICAL |
| Data Protection | 3 | CRITICAL |
| Encryption | 1 | HIGH |

**Total Attack Surface:** 12+ exploitable vulnerabilities

---

## SLIDE 10: Vulnerability #1-2: Outdated Software

### 1. Ubuntu 18.04 LTS (End of Life)
- **Current:** Ubuntu 18.04.6 LTS
- **EOL Date:** April 2023 (1.5+ years outdated)
- **Risk:** Known CVEs, no security patches
- **Impact:** System-level compromise

### 2. MongoDB 4.0.28 (4+ years old)
- **Current:** 4.0.28
- **Latest:** 7.0.x
- **Age:** Released 2021, 4+ years outdated
- **Known CVEs:** Multiple unpatched vulnerabilities
- **Impact:** Database compromise, data exfiltration

**Exploitation Scenario:**
```
Attacker → Scan for outdated MongoDB → Exploit known CVE
         → Gain database access → Extract all data
```

**Wiz Detection:**
- ✅ Software inventory
- ✅ CVE database matching
- ✅ Patch management recommendations

---

## SLIDE 11: Vulnerability #3-4: Network Exposure

### 3. SSH Exposed to Internet (0.0.0.0/0:22)
- **Configuration:** Security group allows SSH from anywhere
- **Risk:** Brute force attacks, credential stuffing
- **Impact:** Full VM compromise

### 4. MongoDB Exposed to Internet (0.0.0.0/0:27017)
- **Configuration:** Database port accessible from anywhere
- **Risk:** Direct database access, data theft
- **Impact:** Complete data breach

**Exploitation Scenario:**
```
Attacker → Port scan discovers 27017 open
         → Connect directly to MongoDB
         → Weak authentication (admin123)
         → Full database access
```

**Wiz Detection:**
- ✅ Network topology mapping
- ✅ Overly permissive security group rules
- ✅ Internet-facing database detection
- ✅ Attack path analysis

---

## SLIDE 12: Vulnerability #5-6: Weak Authentication

### 5. Weak Database Passwords
- **Admin password:** `admin123`
- **App password:** `changeme123`
- **Risk:** Brute force in seconds
- **Impact:** Unauthorized database access

### 6. SSH Password Authentication Enabled
- **Configuration:** `PasswordAuthentication yes`
- **Weak root password:** `Password123`
- **Risk:** Brute force, dictionary attacks
- **Impact:** Root access to VM

**Exploitation Scenario:**
```
Attacker → SSH brute force with common passwords
         → "Password123" succeeds after 100 attempts
         → Root shell access
         → Install crypto miner / backdoor
```

**Wiz Detection:**
- ✅ Secrets scanning
- ✅ Password policy violations
- ✅ Weak credential detection
- ✅ SSH configuration review

---

## SLIDE 13: Vulnerability #7-8: Data Protection

### 7. Public S3 Bucket (Read Access)
- **Configuration:** ACL allows `public-read`
- **Contents:** MongoDB database backups
- **Risk:** Anyone can download backups
- **Impact:** Complete data exfiltration

### 8. Public S3 Bucket Listing Enabled
- **Configuration:** Public listing enabled
- **Risk:** Attacker can enumerate all backups
- **Impact:** Discovery of sensitive data

**Exploitation Scenario:**
```
curl https://mongodb-backups-wiz-123456789.s3.amazonaws.com/
  → Lists all backup files
curl https://.../mongodb_backup_20251021.tar.gz
  → Downloads entire database
tar -xzf mongodb_backup_20251021.tar.gz
  → Extracts all customer data
```

**Live Demo:**
```bash
S3_BUCKET=$(cd terraform && terraform output -raw mongodb_backup_bucket)
aws s3 ls s3://${S3_BUCKET}/
curl -I https://${S3_BUCKET}.s3.amazonaws.com/
```

---

## SLIDE 14: Vulnerability #9: Excessive IAM Permissions

### MongoDB VM IAM Role - Overly Permissive

**Can perform:**
- ✅ `ec2:RunInstances` - Create new VMs
- ✅ `ec2:CreateSecurityGroup` - Create SGs
- ✅ `iam:CreateRole` - Create IAM roles
- ✅ `iam:AttachRolePolicy` - Escalate privileges

**Risk:** Privilege escalation, lateral movement
**Impact:** Complete AWS account compromise

**Exploitation Scenario:**
```
Attacker compromises MongoDB VM
         ↓
Uses instance role to create new EC2 with admin role
         ↓
Launches instance with admin privileges
         ↓
Full AWS account takeover
```

**Wiz Detection:**
- ✅ IAM policy analysis
- ✅ Privilege escalation paths
- ✅ Least privilege recommendations
- ✅ Unused permissions identification

---

## SLIDE 15: Vulnerability #10: Kubernetes RBAC

### Cluster-Admin Role on Application Pods (CRITICAL)

**Configuration:**
```yaml
ClusterRoleBinding: todo-app-admin-binding
Role: cluster-admin
```

**Capabilities:**
- Create/delete any resource in any namespace
- Read all secrets across all namespaces
- Modify RBAC policies
- Access Kubernetes API with full admin rights

**Exploitation Scenario:**
```
Attacker exploits app vulnerability (e.g., RCE)
         ↓
Pod has cluster-admin service account
         ↓
kubectl get secrets --all-namespaces
         ↓
Extracts all Kubernetes secrets
         ↓
Lateral movement to other workloads
```

**Live Demo:**
```bash
kubectl get clusterrolebinding todo-app-admin-binding -o yaml
```

**Wiz Detection:**
- ✅ Kubernetes RBAC analysis
- ✅ Overprivileged service accounts
- ✅ Cluster-admin usage detection
- ✅ Blast radius assessment

---

## SLIDE 16: Vulnerability #11-12: Missing Encryption

### 11. MongoDB - No TLS/SSL
- **Configuration:** Plain text connection
- **Risk:** Man-in-the-middle attacks
- **Impact:** Data interception

### 12. MongoDB Binds to 0.0.0.0
- **Configuration:** Listens on all interfaces
- **Risk:** Accessible from any network
- **Impact:** Increased attack surface

**Wiz Detection:**
- ✅ Encryption in transit verification
- ✅ Network binding analysis
- ✅ Compliance violations (PCI-DSS, HIPAA)

---

## SLIDE 17: DevSecOps Pipeline

### CI/CD Security Integration

**Pipeline 1: Container Build & Scan**
```
GitHub Push → Build Docker Image → Trivy Scan
           → Upload to ECR → Deploy to K8s
```

**Pipeline 2: Infrastructure Scanning**
```
Terraform Change → tfsec → Checkov → Trivy
                → SARIF Upload → GitHub Security
```

**Pipeline 3: Infrastructure Deployment**
```
Manual Trigger → Terraform Plan → Apply
               → Deploy Infrastructure
```

**Security Tools Integrated:**
- **Trivy:** Container & IaC vulnerability scanning
- **tfsec:** Terraform security checks
- **Checkov:** Policy-as-code scanning
- **GitHub Security:** SARIF results upload

---

## SLIDE 18: 🎬 LIVE DEMO - Security Scanning

**Switch to GitHub**

### Show GitHub Actions:
1. Navigate to Actions tab
2. Show "Build and Push Docker Image" workflow
3. Show Trivy scan results
4. Show "Terraform Security Scan" workflow
5. Navigate to Security → Code Scanning
6. Show SARIF upload results

### Run Verification Script:
```bash
./scripts/verify-security-issues.sh
```

**Speaker Notes:**
- "Our CI/CD pipeline automatically scans for security issues"
- "Trivy detected X vulnerabilities in the container"
- "tfsec found Y misconfigurations in Terraform"
- "All results are uploaded to GitHub Security tab for centralized viewing"

---

## SLIDE 19: How Wiz Would Provide Value

### 1. **Unified Visibility**
- Single pane of glass for all cloud resources
- Complete inventory: VMs, containers, K8s, serverless
- Real-time asset discovery

### 2. **Vulnerability Detection**
Without Wiz: Manual scanning, fragmented tools
**With Wiz:**
- ✅ Automatic detection of outdated software
- ✅ CVE matching across entire infrastructure
- ✅ Prioritization based on exploitability

### 3. **Network Path Analysis**
**Wiz shows:**
- Attack paths from internet → database
- Lateral movement possibilities
- Blast radius of each vulnerability

### 4. **Secrets & Configuration**
**Wiz detects:**
- Weak passwords in code/config
- Exposed secrets
- Misconfigured IAM policies
- RBAC violations

### 5. **Compliance & Governance**
**Wiz provides:**
- PCI-DSS, HIPAA, SOC 2 compliance checks
- Policy violations
- Remediation guidance

---

## SLIDE 20: Wiz Detection - Attack Paths

**Example: How Wiz Maps Attack Paths**

```
Internet (Attacker)
    ↓
SSH on MongoDB VM (0.0.0.0/0)
    ↓
Weak Password (Password123)
    ↓
Root Access on VM
    ↓
Overpermissive IAM Role
    ↓
Create new EC2 instance
    ↓
Privilege Escalation
    ↓
AWS Account Takeover
```

**Wiz Priority Score:** CRITICAL
**CVSS:** 9.8
**Exploitability:** HIGH
**Business Impact:** CRITICAL

**Wiz Recommendation:**
1. Remove SSH from internet
2. Use SSH keys only
3. Apply least privilege IAM
4. Enable MFA

---

## SLIDE 21: Risk Reduction with Wiz

### Without Wiz:
- ❌ 12+ critical vulnerabilities undetected
- ❌ No visibility into attack paths
- ❌ Manual compliance checking
- ❌ Fragmented security tools
- ❌ No prioritization

### With Wiz:
- ✅ Automatic discovery of all 12 vulnerabilities
- ✅ Attack path visualization
- ✅ Automated compliance reporting
- ✅ Single platform for all cloud security
- ✅ Risk-based prioritization

**Time to Detection:**
- Manual: Days to weeks
- **Wiz: Minutes**

**Mean Time to Remediate:**
- Manual: Weeks
- **Wiz: Hours** (with guided remediation)

---

## SLIDE 22: Automation & Efficiency

### Automated Deployment
**Created automated scripts for:**
- `setup-prerequisites.sh` - Auto-configure AWS/Terraform
- `deploy-all.sh` - Complete deployment (25-40 min)
- `verify-security-issues.sh` - Validate all vulnerabilities
- `cleanup-all.sh` - Fast teardown (10-15 min with --fast)
- `cleanup-network-dependencies.sh` - Handle VPC dependencies

**Total Lines of Code:**
- Terraform: 387 lines
- Kubernetes: 183 lines
- Scripts: 800+ lines
- Application: 354 lines
- **Total: 1,700+ lines**

**Documentation:**
- README.md (358 lines)
- QUICKSTART.md (294 lines)
- DEPLOYMENT_GUIDE.md (256 lines)
- REQUIREMENTS_CHECKLIST.md (349 lines)
- **Total: 1,250+ lines**

---

## SLIDE 23: Key Takeaways

### Technical Achievement:
✅ Full AWS infrastructure with EKS, EC2, S3, VPC
✅ Containerized application with MongoDB backend
✅ Complete DevSecOps pipeline with security scanning
✅ 12+ intentional vulnerabilities for testing
✅ Comprehensive automation and documentation

### Security Insights:
✅ Demonstrated realistic cloud misconfigurations
✅ Showed attack paths and exploitation scenarios
✅ Illustrated importance of defense in depth
✅ Highlighted value of unified security platform

### DevOps Excellence:
✅ Infrastructure as Code (Terraform)
✅ CI/CD with GitHub Actions
✅ Automated deployment and cleanup
✅ Comprehensive documentation

---

## SLIDE 24: 🎬 LIVE DEMO - Complete Walkthrough

**Final comprehensive demonstration:**

```bash
# 1. Show complete architecture
kubectl get all -n todo-app
aws ec2 describe-instances --filters "Name=tag:Project,Values=wiz-exercise"

# 2. Verify all vulnerabilities
./scripts/verify-security-issues.sh

# 3. Show wizexercise.txt
kubectl exec -n todo-app deployment/todo-app -- cat /app/wizexercise.txt

# 4. Demonstrate application
# Open browser to LoadBalancer URL
# Create todo, show persistence

# 5. Show GitHub Actions
# Navigate to GitHub, show workflows and security scanning

# 6. Show public S3 bucket
S3_BUCKET=$(cd terraform && terraform output -raw mongodb_backup_bucket)
curl -I https://${S3_BUCKET}.s3.amazonaws.com/
```

---

## SLIDE 25: Questions I Anticipate

### Q: Why did you choose AWS over Azure/GCP?
**A:** Familiar with AWS EKS, broader ecosystem, better documentation for intentional misconfigurations

### Q: How would you fix these vulnerabilities?
**A:** [Be ready with specific remediation for each vulnerability]

### Q: What was the hardest part?
**A:** EKS cleanup time (20-30 min) - solved with fast mode automation

### Q: How does this compare to production?
**A:** These are realistic misconfigurations I've seen in real environments

### Q: How would Wiz prioritize these?
**A:** Risk-based: Internet-exposed DB + weak auth = CRITICAL

---

## SLIDE 26: Thank You & Questions

**Contact Information:**
- GitHub: [Your GitHub]
- Email: [Your Email]
- LinkedIn: [Your LinkedIn]

**Repository:**
- https://github.com/ktatavar/SecureTest
- Branch: `claude/wiz-technical-exercise-011CUKeNfwj62DyJWgEkLbNP`

**Resources:**
- Complete documentation in repository
- Automated deployment scripts
- Security verification tools

---

### Q&A Session (15 minutes)

**Be prepared to discuss:**
- Specific Wiz features and how they apply
- Alternative approaches to each vulnerability
- How you'd implement security controls
- Real-world scenarios you've encountered
- Deep dives into any component

---

## APPENDIX: Commands Reference

### Quick Demo Commands
```bash
# Infrastructure
aws eks describe-cluster --name wiz-exercise-cluster --region us-east-1
kubectl get all -n todo-app
terraform output

# Application
kubectl exec -n todo-app deployment/todo-app -- cat /app/wizexercise.txt
kubectl get clusterrolebinding todo-app-admin-binding -o yaml

# Security
./scripts/verify-security-issues.sh
aws s3 ls s3://$(cd terraform && terraform output -raw mongodb_backup_bucket)/

# GitHub
# Navigate to: https://github.com/ktatavar/SecureTest/actions
```

### Backup Commands (if demo fails)
```bash
# Show from screenshots
# Have backup screenshots of:
# - Running infrastructure
# - Application in browser
# - GitHub Actions results
# - Security scan results
```

---

## Presentation Tips

### Delivery:
- Speak clearly and confidently
- Make eye contact (camera)
- Use pauses for emphasis
- Don't rush - you have 45 minutes

### Technical Demo:
- Have terminals pre-positioned
- Test all commands beforehand
- Have backup screenshots ready
- Know your kubectl/aws/terraform commands cold

### Handling Questions:
- Listen fully before answering
- It's okay to say "I don't know, but here's how I'd find out"
- Relate back to Wiz features when possible
- Be honest about trade-offs and decisions

### Time Management:
- Spend 60% on demo, 40% on slides
- Keep introduction brief (3 min)
- Deep dive on 3-4 vulnerabilities, overview others
- Save 15 minutes for Q&A

---

## Pre-Presentation Checklist

**24 Hours Before:**
- [ ] Test complete deployment end-to-end
- [ ] Verify all commands work
- [ ] Take screenshots as backup
- [ ] Review Wiz documentation
- [ ] Practice presentation twice

**1 Hour Before:**
- [ ] Deploy infrastructure if not already deployed
- [ ] Test application is accessible
- [ ] Verify wizexercise.txt is in container
- [ ] Open all necessary terminals
- [ ] Position browser windows
- [ ] Check internet connection
- [ ] Have GitHub open in browser

**5 Minutes Before:**
- [ ] Deep breath
- [ ] Water nearby
- [ ] All demos tested one last time
- [ ] Mute notifications
- [ ] Ready to screen share

---

Good luck with your presentation! 🚀
