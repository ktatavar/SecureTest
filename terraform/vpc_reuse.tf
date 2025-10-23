# VPC Reuse Configuration
# This allows reusing an existing VPC instead of creating a new one

# Data source to find existing VPC by tag
data "aws_vpcs" "existing" {
  tags = {
    Name = "wiz-exercise-vpc"
  }
}

# Check if VPC exists
locals {
  vpc_exists = length(data.aws_vpcs.existing.ids) > 0
  vpc_id     = local.vpc_exists ? tolist(data.aws_vpcs.existing.ids)[0] : aws_vpc.main[0].id
}

# Conditionally create VPC only if it doesn't exist
resource "aws_vpc" "main" {
  count = local.vpc_exists ? 0 : 1
  
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wiz-exercise-vpc"
  }
  
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags]
  }
}

# Data source for existing VPC details
data "aws_vpc" "selected" {
  id = local.vpc_id
}

# Data sources for existing subnets (if VPC exists)
data "aws_subnets" "public" {
  count = local.vpc_exists ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  
  tags = {
    Type = "public"
  }
}

data "aws_subnets" "private" {
  count = local.vpc_exists ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  
  tags = {
    Type = "private"
  }
}

# Output to show if VPC was reused or created
output "vpc_reused" {
  value       = local.vpc_exists
  description = "Whether an existing VPC was reused (true) or a new one was created (false)"
}

output "vpc_id_in_use" {
  value       = local.vpc_id
  description = "The VPC ID being used"
}
