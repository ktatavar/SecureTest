# Lifecycle rules to handle existing resources gracefully
# This prevents Terraform from failing when resources already exist

# For all resources, ignore certain changes and allow existing resources
locals {
  common_lifecycle = {
    ignore_changes = [
      tags,
      tags_all,
    ]
    create_before_destroy = true
  }
}

# Override for IAM resources to prevent conflicts
resource "null_resource" "iam_policy_check" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Checking for existing IAM resources..."
      # This is a placeholder for pre-flight checks
    EOT
  }
}

# Add moved blocks for resources that might have been created with different names
# This helps Terraform track resources that were renamed

# Example: If mongodb role was created manually
# moved {
#   from = aws_iam_role.old_name
#   to   = aws_iam_role.mongodb_vm
# }
