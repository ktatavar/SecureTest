# How to Enable EKS Control Plane Logging

## Quick Enable (1 minute)

### Step 1: Edit Terraform Configuration

Open `terraform/main.tf` and uncomment line 331 or 334:

**Option A: Enable All Logs (Full Visibility)**
```hcl
# Line 331 - Uncomment this line:
cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
```

**Option B: Enable Critical Logs Only (Recommended for Production)**
```hcl
# Line 334 - Uncomment this line:
cluster_enabled_log_types = ["api", "audit"]
```

### Step 2: Apply Changes

```bash
cd terraform
terraform apply -auto-approve
```

**Time:** ~2-3 minutes

### Step 3: Verify Logs in CloudWatch

```bash
# Check log groups created
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/wiz-exercise-cluster-v2 \
  --region us-east-1

# View recent API server logs
aws logs tail /aws/eks/wiz-exercise-cluster-v2/cluster \
  --follow \
  --region us-east-1
```

---

## What Each Log Type Provides

| Log Type | What It Captures | Use Case | Priority |
|----------|------------------|----------|----------|
| **api** | All API server requests (kubectl commands, API calls) | Security monitoring, audit trails | **HIGH** |
| **audit** | Kubernetes audit events (who did what, when) | Compliance (SOC2, PCI-DSS), security investigations | **HIGH** |
| **authenticator** | IAM authentication attempts | Troubleshooting IAM/OIDC issues | MEDIUM |
| **controllerManager** | Controller manager operations | Operational debugging | LOW |
| **scheduler** | Pod scheduling decisions | Performance troubleshooting | LOW |

---

## Cost Breakdown

### CloudWatch Logs Pricing (us-east-1)
- **Ingestion**: $0.50 per GB
- **Storage**: $0.03 per GB per month
- **Queries**: $0.005 per GB scanned

### Estimated Costs

| Scenario | Daily Logs | Monthly Ingestion | Monthly Storage | Total/Month |
|----------|-----------|-------------------|-----------------|-------------|
| **All 5 log types** | 3-5 GB | $45-75 | $3-5 | **$48-80** |
| **API + Audit only** | 1-2 GB | $15-30 | $1-2 | **$16-32** |
| **Low activity cluster** | 0.5-1 GB | $7.50-15 | $0.50-1 | **$8-16** |

**For this demo environment:** ~$15-30/month (API + audit logs)

---

## When to Enable

### ✅ Enable If:
- Your role requires cloud native security expertise
- Presenting to security-focused panel
- Want to demonstrate CloudWatch integration
- Need to show compliance capabilities
- Troubleshooting cluster issues

### ❌ Keep Disabled If:
- Cost-sensitive demo environment
- Short-term testing only
- Not required for your specific role
- Can demonstrate knowledge without actual logs

---

## Demo During Presentation

### If Disabled (Current State):

**What to Say:**
> "Control plane audit logging is available but currently disabled to minimize costs for this demo. It's a one-line change in Terraform to enable. In production, I'd enable at minimum the API and audit logs for security monitoring and compliance requirements like SOC2 or PCI-DSS."

**Show the Code:**
```bash
# Show the commented configuration
cat terraform/main.tf | grep -A 5 "Control Plane Logging"
```

### If Enabled:

**What to Demonstrate:**
```bash
# 1. Show log groups exist
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/wiz-exercise-cluster-v2

# 2. Show recent kubectl commands in logs
aws logs tail /aws/eks/wiz-exercise-cluster-v2/cluster \
  --since 10m \
  --filter-pattern "kubectl"

# 3. Show audit events
aws logs tail /aws/eks/wiz-exercise-cluster-v2/cluster \
  --since 10m \
  --filter-pattern "audit"

# 4. Open CloudWatch Console
# Navigate to: CloudWatch > Log groups > /aws/eks/wiz-exercise-cluster-v2
```

---

## Production Best Practices

### Recommended Configuration

```hcl
module "eks" {
  # ... other config ...
  
  # Enable critical logs only
  cluster_enabled_log_types = ["api", "audit"]
  
  # Optional: Set log retention
  cloudwatch_log_group_retention_in_days = 90  # or 30, 180, 365
}
```

### Log Retention Policies

| Retention | Use Case | Cost Impact |
|-----------|----------|-------------|
| 7 days | Development/testing | Minimal |
| 30 days | Standard production | Low |
| 90 days | Compliance (most regulations) | Medium |
| 365 days | Long-term audit requirements | High |

### Integration with SIEM

```bash
# Export logs to S3 for long-term storage
aws logs create-export-task \
  --log-group-name /aws/eks/wiz-exercise-cluster-v2/cluster \
  --from $(date -d '7 days ago' +%s)000 \
  --to $(date +%s)000 \
  --destination s3-bucket-name \
  --destination-prefix eks-logs/

# Stream to external SIEM (Splunk, Datadog, etc.)
# Use CloudWatch Logs subscription filters
```

---

## Troubleshooting

### Logs Not Appearing

```bash
# Check if logging is enabled
aws eks describe-cluster \
  --name wiz-exercise-cluster-v2 \
  --query 'cluster.logging' \
  --region us-east-1

# Check CloudWatch log group exists
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/wiz-exercise-cluster-v2

# Generate some activity
kubectl get pods -A
kubectl get nodes
```

### High Costs

```bash
# Check log ingestion volume
aws cloudwatch get-metric-statistics \
  --namespace AWS/Logs \
  --metric-name IncomingBytes \
  --dimensions Name=LogGroupName,Value=/aws/eks/wiz-exercise-cluster-v2/cluster \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum

# Reduce to critical logs only
# Edit terraform/main.tf: cluster_enabled_log_types = ["api", "audit"]
```

---

## Cleanup

### Disable Logging

```bash
# Comment out the line in terraform/main.tf
# Then apply:
cd terraform
terraform apply -auto-approve
```

### Delete Log Groups

```bash
# Logs are retained even after disabling
# To delete (careful - irreversible):
aws logs delete-log-group \
  --log-group-name /aws/eks/wiz-exercise-cluster-v2/cluster \
  --region us-east-1
```

---

## Summary

- **Current Status**: Disabled (commented in code)
- **Enable Time**: 2-3 minutes
- **Cost**: $15-30/month for demo cluster
- **Value**: Compliance, security monitoring, audit trails
- **Recommendation**: Enable only if required for your role or presentation

**For most presentations, demonstrating knowledge of the feature is sufficient without incurring the actual cost.**
