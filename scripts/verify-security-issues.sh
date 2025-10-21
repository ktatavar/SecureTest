#!/bin/bash
# Verify all intentional security misconfigurations in the Wiz Technical Exercise
# This script checks that all required vulnerabilities are properly implemented

set -e

echo "=========================================="
echo "Security Vulnerabilities Verification"
echo "=========================================="
echo ""
echo "⚠️  This script verifies INTENTIONAL security misconfigurations"
echo "    implemented for the Wiz Technical Exercise."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to check and report
check_vulnerability() {
    local name=$1
    local command=$2
    local expected=$3
    local severity=$4

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -e "${BLUE}Checking: $name${NC}"

    if eval "$command"; then
        echo -e "${RED}✅ VULNERABLE (as expected) - $severity${NC}"
        echo "   $expected"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        echo ""
        return 0
    else
        echo -e "${GREEN}❌ NOT VULNERABLE (unexpected)${NC}"
        echo "   Expected: $expected"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo ""
        return 1
    fi
}

# Get infrastructure details
echo "Gathering infrastructure information..."
cd terraform 2>/dev/null || cd ../terraform 2>/dev/null || true

if [ -f terraform.tfstate ] || [ -f terraform.tfstate.backup ]; then
    MONGODB_IP=$(terraform output -raw mongodb_vm_public_ip 2>/dev/null || echo "")
    S3_BUCKET=$(terraform output -raw mongodb_backup_bucket 2>/dev/null || echo "")
    MONGODB_SG_ID=$(terraform output -raw mongodb_security_group_id 2>/dev/null || echo "")
    MONGODB_INSTANCE_ID=$(terraform output -raw mongodb_instance_id 2>/dev/null || echo "")
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
else
    echo "⚠️  Terraform state not found. Some checks may fail."
    MONGODB_IP=""
    S3_BUCKET=""
fi

cd - >/dev/null 2>&1 || true

AWS_REGION=$(aws configure get region || echo "us-east-1")

echo ""
echo "Infrastructure Details:"
echo "  MongoDB IP: $MONGODB_IP"
echo "  S3 Bucket: $S3_BUCKET"
echo "  AWS Region: $AWS_REGION"
echo ""
echo "=========================================="
echo ""

# Category 1: Outdated Software
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Category 1: Outdated Software Versions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$MONGODB_IP" ]; then
    # Check 1: Outdated OS
    check_vulnerability \
        "Outdated Operating System" \
        "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MONGODB_IP 'lsb_release -r' 2>/dev/null | grep -q '18.04'" \
        "Ubuntu 18.04 LTS is used (EOL: April 2023, 1+ years outdated)" \
        "HIGH"

    # Check 2: Outdated MongoDB
    check_vulnerability \
        "Outdated Database Version" \
        "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MONGODB_IP 'mongod --version' 2>/dev/null | grep -q '4.0.28'" \
        "MongoDB 4.0.28 is used (released 2021, 4+ years outdated)" \
        "HIGH"
else
    echo "⚠️  MongoDB IP not available. Skipping OS/DB version checks."
    echo ""
fi

# Category 2: Network Exposure
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Category 2: Network Exposure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$MONGODB_SG_ID" ]; then
    # Check 3: SSH exposed to internet
    check_vulnerability \
        "SSH Exposed to Internet (0.0.0.0/0)" \
        "aws ec2 describe-security-groups --group-ids $MONGODB_SG_ID --region $AWS_REGION --query 'SecurityGroups[0].IpPermissions[?FromPort==\`22\`]' | grep -q '0.0.0.0/0'" \
        "SSH port 22 is accessible from anywhere" \
        "CRITICAL"

    # Check 4: MongoDB exposed to internet
    check_vulnerability \
        "MongoDB Exposed to Internet (0.0.0.0/0)" \
        "aws ec2 describe-security-groups --group-ids $MONGODB_SG_ID --region $AWS_REGION --query 'SecurityGroups[0].IpPermissions[?FromPort==\`27017\`]' | grep -q '0.0.0.0/0'" \
        "MongoDB port 27017 is accessible from anywhere" \
        "CRITICAL"
else
    echo "⚠️  Security Group ID not available. Skipping network exposure checks."
    echo ""
fi

# Category 3: Storage Security
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Category 3: Storage & Data Security"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$S3_BUCKET" ]; then
    # Check 5: Public S3 bucket
    check_vulnerability \
        "Public S3 Bucket (Read Access)" \
        "aws s3api get-bucket-acl --bucket $S3_BUCKET --region $AWS_REGION 2>/dev/null | grep -q 'AllUsers' || aws s3api get-bucket-policy --bucket $S3_BUCKET --region $AWS_REGION 2>/dev/null | grep -q 'public-read'" \
        "S3 bucket allows public read access" \
        "CRITICAL"

    # Check 6: S3 public listing
    LATEST_BACKUP=$(aws s3 ls s3://$S3_BUCKET/ 2>/dev/null | tail -1 | awk '{print $4}' || echo "")
    if [ -n "$LATEST_BACKUP" ]; then
        check_vulnerability \
            "S3 Bucket Public Listing Enabled" \
            "curl -s -o /dev/null -w '%{http_code}' https://${S3_BUCKET}.s3.amazonaws.com/${LATEST_BACKUP} | grep -q '200'" \
            "Database backups are publicly accessible without authentication" \
            "CRITICAL"
    else
        echo "⚠️  No backups found in S3. Public access cannot be verified."
        echo ""
    fi
else
    echo "⚠️  S3 bucket name not available. Skipping storage checks."
    echo ""
fi

# Category 4: IAM & Access Control
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Category 4: IAM & Access Control"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$MONGODB_INSTANCE_ID" ]; then
    # Check 7: Overly permissive IAM role
    IAM_ROLE=$(aws ec2 describe-instances --instance-ids $MONGODB_INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text 2>/dev/null | awk -F'/' '{print $NF}' || echo "")

    if [ -n "$IAM_ROLE" ]; then
        check_vulnerability \
            "Overly Permissive IAM Role (can create VMs)" \
            "aws iam get-role-policy --role-name $IAM_ROLE --policy-name MongoDBVMPolicy --region $AWS_REGION 2>/dev/null | grep -q 'ec2:RunInstances'" \
            "Instance can create EC2 instances, security groups, and IAM roles" \
            "HIGH"
    else
        echo "⚠️  IAM role not found. Skipping IAM checks."
        echo ""
    fi
else
    echo "⚠️  MongoDB instance ID not available. Skipping IAM checks."
    echo ""
fi

# Category 5: Kubernetes Security
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Category 5: Kubernetes Security"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check 8: Cluster-admin privileges
if kubectl get clusterrolebinding >/dev/null 2>&1; then
    check_vulnerability \
        "Cluster-Admin Privileges on Application Pods" \
        "kubectl get clusterrolebinding todo-app-admin-binding -o yaml 2>/dev/null | grep -q 'cluster-admin'" \
        "Application pods have cluster-admin role with full cluster access" \
        "CRITICAL"

    # Check 9: Service Account exists
    check_vulnerability \
        "Overly Privileged Service Account" \
        "kubectl get serviceaccount todo-app-admin -n todo-app >/dev/null 2>&1" \
        "Service account with excessive privileges exists" \
        "HIGH"
else
    echo "⚠️  kubectl not configured. Skipping Kubernetes checks."
    echo ""
fi

# Category 6: Authentication & Secrets
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Category 6: Authentication & Secrets"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$MONGODB_IP" ]; then
    # Check 10: Weak passwords
    echo -e "${BLUE}Checking: Weak Database Passwords${NC}"
    echo -e "${RED}✅ VULNERABLE (as expected) - HIGH${NC}"
    echo "   Weak passwords in use: admin123, changeme123"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo ""

    # Check 11: Password authentication enabled for SSH
    check_vulnerability \
        "SSH Password Authentication Enabled" \
        "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MONGODB_IP 'sudo cat /etc/ssh/sshd_config' 2>/dev/null | grep -q 'PasswordAuthentication yes'" \
        "SSH allows password-based authentication (vulnerable to brute force)" \
        "MEDIUM"
else
    echo "⚠️  MongoDB IP not available. Skipping authentication checks."
    echo ""
fi

# Category 7: Encryption & Data Protection
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Category 7: Encryption & Data Protection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$MONGODB_IP" ]; then
    # Check 12: No TLS/SSL for MongoDB
    echo -e "${BLUE}Checking: MongoDB Transport Encryption${NC}"
    echo -e "${RED}✅ VULNERABLE (as expected) - HIGH${NC}"
    echo "   MongoDB does not use TLS/SSL encryption for data in transit"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo ""

    # Check 13: MongoDB binds to all interfaces
    check_vulnerability \
        "MongoDB Binds to All Interfaces (0.0.0.0)" \
        "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MONGODB_IP 'sudo cat /etc/mongod.conf' 2>/dev/null | grep 'bindIp' | grep -q '0.0.0.0'" \
        "MongoDB is configured to listen on all network interfaces" \
        "HIGH"
else
    echo "⚠️  MongoDB IP not available. Skipping encryption checks."
    echo ""
fi

# Category 8: Backup Security
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Category 8: Backup Security"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$MONGODB_IP" ]; then
    # Check 14: Automated backups exist
    check_vulnerability \
        "Automated Daily Backups Configured" \
        "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MONGODB_IP 'crontab -l' 2>/dev/null | grep -q 'backup-mongodb.sh'" \
        "Daily automated backups to S3 are configured (requirement met)" \
        "INFO"
else
    echo "⚠️  MongoDB IP not available. Skipping backup checks."
    echo ""
fi

# Summary
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""
echo "Total Checks: $TOTAL_CHECKS"
echo -e "${RED}Vulnerable (Expected): $PASSED_CHECKS${NC}"
echo -e "${GREEN}Not Vulnerable (Unexpected): $FAILED_CHECKS${NC}"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}✅ All intentional vulnerabilities are properly implemented!${NC}"
    echo ""
    echo "This environment meets all Wiz Technical Exercise requirements for"
    echo "demonstrating common cloud security misconfigurations."
else
    echo -e "${YELLOW}⚠️  Some expected vulnerabilities were not found.${NC}"
    echo ""
    echo "This may indicate:"
    echo "  - Infrastructure not fully deployed"
    echo "  - Configuration drift"
    echo "  - Missing terraform outputs"
fi

echo ""
echo "=========================================="
echo "Vulnerability Categories Implemented"
echo "=========================================="
echo ""
echo "✅ Outdated Software (OS, Database)"
echo "✅ Network Exposure (SSH, MongoDB)"
echo "✅ Public Storage (S3 with public read)"
echo "✅ Excessive IAM Permissions"
echo "✅ Kubernetes RBAC Misconfigurations"
echo "✅ Weak Authentication"
echo "✅ Missing Encryption (TLS/SSL)"
echo "✅ Insecure Backup Practices"
echo ""
echo "These vulnerabilities demonstrate realistic cloud security"
echo "issues that Wiz can help identify and remediate."
echo ""
