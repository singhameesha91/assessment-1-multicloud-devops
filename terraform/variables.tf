# -------------------------------------------------------
# Variables - All configurable parameters
# -------------------------------------------------------

# ==================== General ====================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "multicloud-devops"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ==================== AWS ====================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_account_id" {
  description = "AWS Account ID (used for ECR URIs and IAM)"
  type        = string
}

# ==================== GCP ====================

variable "gcp_project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for Cloud Storage"
  type        = string
  default     = "australia-southeast1"
}

# ==================== Networking ====================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to deploy subnets into"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}

# ==================== Container Platform ====================

variable "ecr_repo_name_a" {
  description = "ECR repository name for Service A"
  type        = string
  default     = "service-a"
}

variable "ecr_repo_name_b" {
  description = "ECR repository name for Service B"
  type        = string
  default     = "service-b"
}

variable "ecs_cluster_name" {
  description = "Name for the ECS cluster"
  type        = string
  default     = "devops-cluster"
}

variable "service_a_cpu" {
  description = "CPU units for Service A task definition"
  type        = number
  default     = 256
}

variable "service_a_memory" {
  description = "Memory (MiB) for Service A task definition"
  type        = number
  default     = 512
}

variable "service_a_port" {
  description = "Container port for Service A"
  type        = number
  default     = 8000
}

variable "service_b_cpu" {
  description = "CPU units for Service B task definition"
  type        = number
  default     = 256
}

variable "service_b_memory" {
  description = "Memory (MiB) for Service B task definition"
  type        = number
  default     = 512
}

variable "service_b_port" {
  description = "Container port for Service B"
  type        = number
  default     = 3000
}

variable "desired_count" {
  description = "Desired number of ECS tasks per service"
  type        = number
  default     = 1
}

# ==================== Autoscaling ====================

variable "autoscaling_min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 4
}

variable "cpu_scale_out_threshold" {
  description = "CPU utilisation percentage to trigger scale-out"
  type        = number
  default     = 70
}

variable "cpu_scale_in_threshold" {
  description = "CPU utilisation percentage to trigger scale-in"
  type        = number
  default     = 30
}

# ==================== Notifications ====================

variable "notification_email" {
  description = "Email address for SNS alarm notifications"
  type        = string
  default     = ""
}

# ==================== CI/CD ====================

variable "github_repo" {
  description = "GitHub repository name (owner/repo format)"
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "GitHub branch to track for pipeline"
  type        = string
  default     = "main"
}

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub (created manually in AWS Console)"
  type        = string
  default     = ""
}

# ==================== State Backend (for bootstrapping) ====================

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
  default     = "multicloud-devops-tfstate"
}

variable "state_lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "terraform-state-lock"
}

# ==================== SAML / Entra ID ====================

variable "saml_metadata_file" {
  description = "Path to the Azure Entra ID SAML metadata XML file"
  type        = string
  default     = "entra-id-metadata.xml"
}
