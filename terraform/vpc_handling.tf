# VPC Handling - Use existing VPC if available or create new one

# Check for existing VPC with our tag
data "aws_vpcs" "existing" {
  tags = {
    Name = "wiz-exercise-vpc"
  }
}

# Use existing VPC if found, otherwise create new one
locals {
  use_existing_vpc = length(data.aws_vpcs.existing.ids) > 0
  vpc_id           = local.use_existing_vpc ? tolist(data.aws_vpcs.existing.ids)[0] : aws_vpc.main[0].id
}

# Conditional VPC creation - only create if doesn't exist
resource "aws_vpc" "main" {
  count = local.use_existing_vpc ? 0 : 1
  
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wiz-exercise-vpc"
  }
}

# Get existing VPC details if using existing
data "aws_vpc" "selected" {
  count = local.use_existing_vpc ? 1 : 0
  id    = tolist(data.aws_vpcs.existing.ids)[0]
}

# Output which VPC is being used
output "vpc_source" {
  value = local.use_existing_vpc ? "existing" : "new"
}

output "vpc_id_used" {
  value = local.vpc_id
}
