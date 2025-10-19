variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "wiz-exercise-cluster"
}

variable "s3_backup_bucket_name" {
  description = "S3 bucket name for MongoDB backups"
  type        = string
  default     = "mongodb-backups-insecure-unique-12345"  # Change to unique name
}

variable "ubuntu_1804_ami" {
  description = "Ubuntu 18.04 LTS AMI (OUTDATED)"
  type        = string
  # AMI IDs vary by region - these are examples for us-east-1
  # Ubuntu 18.04 LTS (Bionic) - OUTDATED
  default     = "ami-0a313d6098716f372"  # Update with actual AMI ID for your region
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "Wiz-Technical-Exercise"
    Environment = "insecure-by-design"
    ManagedBy   = "Terraform"
  }
}
