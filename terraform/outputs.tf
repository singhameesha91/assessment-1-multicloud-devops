# -------------------------------------------------------
# Outputs - Key resource identifiers and endpoints
# -------------------------------------------------------

# ==================== Networking ====================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

# ==================== ALB Endpoints ====================

output "alb_service_a_dns" {
  description = "DNS name of the ALB for Service A"
  value       = aws_lb.service_a.dns_name
}

output "alb_service_b_dns" {
  description = "DNS name of the ALB for Service B"
  value       = aws_lb.service_b.dns_name
}

output "service_a_url" {
  description = "Full URL for Service A"
  value       = "http://${aws_lb.service_a.dns_name}"
}

output "service_b_url" {
  description = "Full URL for Service B"
  value       = "http://${aws_lb.service_b.dns_name}"
}

# ==================== ECR ====================

output "ecr_repo_url_service_a" {
  description = "ECR repository URL for Service A"
  value       = aws_ecr_repository.service_a.repository_url
}

output "ecr_repo_url_service_b" {
  description = "ECR repository URL for Service B"
  value       = aws_ecr_repository.service_b.repository_url
}

# ==================== ECS ====================

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

# ==================== Data & Storage ====================

output "dynamodb_table_name" {
  description = "Name of the DynamoDB transactions table"
  value       = aws_dynamodb_table.transactions.name
}

output "s3_pipeline_bucket" {
  description = "S3 bucket for CodePipeline artifacts"
  value       = aws_s3_bucket.pipeline_artifacts.id
}

output "gcp_assets_bucket" {
  description = "GCP Cloud Storage bucket for application assets"
  value       = google_storage_bucket.app_assets.name
}

# ==================== Notifications ====================

output "sns_topic_arn" {
  description = "ARN of the SNS notification topic"
  value       = aws_sns_topic.notifications.arn
}

# ==================== CI/CD ====================

output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = var.codestar_connection_arn != "" ? aws_codepipeline.main[0].name : "not-created (set codestar_connection_arn)"
}
