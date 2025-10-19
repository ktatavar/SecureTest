# Terraform Outputs

output "summary" {
  description = "Deployment summary with security warnings"
  value = <<-EOT
  
  ========================================
  Wiz Technical Exercise - Deployment Summary
  ========================================
  
  MongoDB VM:
    Public IP: ${aws_instance.mongodb_vm.public_ip}
    SSH: ssh ubuntu@${aws_instance.mongodb_vm.public_ip}
    Connection: mongodb://todouser:changeme123@${aws_instance.mongodb_vm.public_ip}:27017/todoapp
  
  S3 Backup Bucket:
    Name: ${aws_s3_bucket.mongodb_backups.id}
    Public URL: https://${aws_s3_bucket.mongodb_backups.bucket}.s3.amazonaws.com/
  
  EKS Cluster:
    Name: ${module.eks.cluster_name}
    Endpoint: ${module.eks.cluster_endpoint}
    Configure: aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
  
  ⚠️  SECURITY WARNINGS (BY DESIGN):
    ✗ MongoDB VM running Ubuntu 18.04 (OUTDATED)
    ✗ MongoDB 4.4.18 (OUTDATED)
    ✗ SSH exposed to 0.0.0.0/0
    ✗ MongoDB exposed to 0.0.0.0/0
    ✗ Overly permissive IAM role (can create VMs)
    ✗ S3 bucket with public read access
    ✗ S3 bucket with public listing enabled
    ✗ Weak passwords in use
  
  Next Steps:
    1. Configure kubectl: aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
    2. Build and push Docker image
    3. Update k8s/deployment.yaml with your image
    4. Deploy: kubectl apply -f k8s/
    5. Get LoadBalancer URL: kubectl get svc -n todo-app todo-app-loadbalancer
  
  ========================================
  EOT
}
