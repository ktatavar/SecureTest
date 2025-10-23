# GitHub Actions IAM Role and Policies
# This role is used by GitHub Actions workflows to deploy infrastructure and applications

data "aws_caller_identity" "current" {}

# Use existing IAM policy if it exists, otherwise this will be managed outside Terraform
data "aws_iam_policy" "github_actions_terraform" {
  name = "GitHubActionsTerraformPolicy"
}

# Commented out - policy already exists and is managed by setup script
# Uncomment if you want Terraform to manage the policy
/*
resource "aws_iam_policy" "github_actions_terraform" {
  name        = "GitHubActionsTerraformPolicy"
  description = "Permissions for GitHub Actions to run Terraform and deploy infrastructure"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR Permissions
      {
        Sid    = "ECRFullAccess"
        Effect = "Allow"
        Action = [
          "ecr:*"
        ]
        Resource = "*"
      },
      # EKS Permissions
      {
        Sid    = "EKSFullAccess"
        Effect = "Allow"
        Action = [
          "eks:*"
        ]
        Resource = "*"
      },
      # EC2 Permissions
      {
        Sid    = "EC2FullAccess"
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      },
      # IAM Read Permissions
      {
        Sid    = "IAMReadAccess"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetInstanceProfile",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:ListPolicies",
          "iam:ListInstanceProfiles",
          "iam:ListInstanceProfilesForRole"
        ]
        Resource = "*"
      },
      # IAM Write Permissions
      {
        Sid    = "IAMWriteAccess"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:PassRole",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider"
        ]
        Resource = "*"
      },
      # S3 Permissions
      {
        Sid    = "S3FullAccess"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      },
      # VPC Permissions
      {
        Sid    = "VPCFullAccess"
        Effect = "Allow"
        Action = [
          "vpc:*"
        ]
        Resource = "*"
      },
      # CloudWatch Logs
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:*"
        ]
        Resource = "*"
      },
      # KMS Permissions
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:PutKeyPolicy",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:UpdateAlias",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:EnableKeyRotation",
          "kms:DisableKeyRotation"
        ]
        Resource = "*"
      },
      # Auto Scaling
      {
        Sid    = "AutoScalingAccess"
        Effect = "Allow"
        Action = [
          "autoscaling:*"
        ]
        Resource = "*"
      },
      # Elastic Load Balancing
      {
        Sid    = "ELBAccess"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      },
      # STS (for assuming roles)
      {
        Sid    = "STSAccess"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "sts:GetSessionToken"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "GitHubActionsTerraformPolicy"
    ManagedBy   = "Terraform"
    Purpose     = "GitHub Actions CI/CD"
    Environment = "all"
  }
}
*/

# Attach the policy to the existing GitHub Actions role
# This uses the data source, so it won't fail if policy already exists
resource "aws_iam_role_policy_attachment" "github_actions_terraform" {
  role       = "GitHubActionsECRRole"
  policy_arn = data.aws_iam_policy.github_actions_terraform.arn
  
  lifecycle {
    create_before_destroy = true
  }
}

# Output the policy ARN
output "github_actions_policy_arn" {
  description = "ARN of the GitHub Actions Terraform policy"
  value       = data.aws_iam_policy.github_actions_terraform.arn
}
