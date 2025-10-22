terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wiz-exercise-vpc"
  }
}

# Public Subnet (for Load Balancer and Kubernetes public subnet)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name                                           = "wiz-public-subnet"
    "kubernetes.io/role/elb"                       = "1"
    "kubernetes.io/cluster/${var.cluster_name}"    = "shared"
  }
}

# Private Subnet 1 (for Kubernetes pods)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name                                           = "wiz-private-subnet-a"
    "kubernetes.io/role/internal-elb"              = "1"
    "kubernetes.io/cluster/${var.cluster_name}"    = "shared"
    "subnet-type"                                  = "private"
  }
}

# Private Subnet 2 (for Kubernetes pods - second AZ)
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name                                           = "wiz-private-subnet-b"
    "kubernetes.io/role/internal-elb"              = "1"
    "kubernetes.io/cluster/${var.cluster_name}"    = "shared"
    "subnet-type"                                  = "private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "wiz-igw"
  }
}

# NAT Gateway for private subnet
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "wiz-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "wiz-nat-gateway"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "wiz-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "wiz-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Security Group for MongoDB VM (INSECURE - as per requirements)
resource "aws_security_group" "mongodb_vm" {
  name        = "mongodb-vm-sg"
  description = "INSECURE: Security group for MongoDB VM - SSH and MongoDB exposed to internet"
  vpc_id      = aws_vpc.main.id

  # SSH exposed to internet (INSECURE)
  ingress {
    description = "SSH from anywhere (INSECURE)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MongoDB exposed to internet (INSECURE)
  ingress {
    description = "MongoDB from anywhere (INSECURE)"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mongodb-vm-sg-insecure"
  }
}

# IAM Role for MongoDB VM (OVERLY PERMISSIVE - as per requirements)
resource "aws_iam_role" "mongodb_vm" {
  name = "mongodb-vm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "mongodb-vm-role-overpermissive"
  }
}

# OVERLY PERMISSIVE IAM Policy (as per requirements)
resource "aws_iam_role_policy" "mongodb_vm_policy" {
  name = "mongodb-vm-policy"
  role = aws_iam_role.mongodb_vm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeSecurityGroups",
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "${aws_s3_bucket.mongodb_backups.arn}",
          "${aws_s3_bucket.mongodb_backups.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mongodb_vm" {
  name = "mongodb-vm-profile"
  role = aws_iam_role.mongodb_vm.name
}

# MongoDB VM Instance (OUTDATED OS)
resource "aws_instance" "mongodb_vm" {
  # Ubuntu 18.04 LTS (OUTDATED - EOL April 2023)
  ami           = var.ubuntu_1804_ami
  instance_type = "t3.medium"
  key_name      = "mongodb-vm-key"  # SSH key for access
  
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.mongodb_vm.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.mongodb_vm.name

  user_data = file("${path.module}/../mongodb-vm/cloud-init.yaml")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "mongodb-vm-outdated"
  }
}

# S3 Bucket for MongoDB Backups (PUBLIC - INSECURE)
resource "aws_s3_bucket" "mongodb_backups" {
  bucket = var.s3_backup_bucket_name

  tags = {
    Name = "mongodb-backups-public-insecure"
  }
}

# INSECURE: Public access block disabled
# Note: This may be blocked by account-level settings
resource "aws_s3_bucket_public_access_block" "mongodb_backups" {
  bucket = aws_s3_bucket.mongodb_backups.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Wait for public access block to be applied
resource "time_sleep" "wait_for_public_access_block" {
  depends_on = [aws_s3_bucket_public_access_block.mongodb_backups]
  create_duration = "10s"
}

# INSECURE: Public read policy
# Note: This requires account-level Block Public Access to be disabled
resource "aws_s3_bucket_policy" "mongodb_backups_public" {
  bucket = aws_s3_bucket.mongodb_backups.id
  depends_on = [time_sleep.wait_for_public_access_block]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "${aws_s3_bucket.mongodb_backups.arn}",
          "${aws_s3_bucket.mongodb_backups.arn}/*"
        ]
      }
    ]
  })
}

# EKS Cluster for Kubernetes
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.28"

  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.public.id, aws_subnet.private.id, aws_subnet.private_b.id]

  enable_irsa = true

  # Control Plane Logging (Optional - Currently Disabled)
  # Uncomment to enable CloudWatch logging for EKS control plane
  # Cost: ~$15-75/month depending on cluster activity
  # Useful for: Compliance, audit trails, security monitoring, troubleshooting
  # cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  # To enable only critical logs (recommended for production):
  # cluster_enabled_log_types = ["api", "audit"]

  eks_managed_node_groups = {
    private = {
      name = "private-node-group"

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 2
      max_size     = 4
      desired_size = 2

      subnet_ids = [aws_subnet.private.id, aws_subnet.private_b.id]

      labels = {
        "subnet-type" = "private"
      }
    }
  }

  tags = {
    Environment = "wiz-exercise"
  }
}

# Outputs
output "mongodb_vm_public_ip" {
  description = "Public IP of MongoDB VM"
  value       = aws_instance.mongodb_vm.public_ip
}

output "mongodb_connection_string" {
  description = "MongoDB connection string"
  value       = "mongodb://todouser:changeme123@${aws_instance.mongodb_vm.public_ip}:27017/todoapp"
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 bucket for MongoDB backups"
  value       = aws_s3_bucket.mongodb_backups.id
}

output "s3_bucket_url" {
  description = "Public URL of S3 bucket (INSECURE)"
  value       = "https://${aws_s3_bucket.mongodb_backups.bucket}.s3.amazonaws.com/"
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
