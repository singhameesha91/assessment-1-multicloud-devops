# -------------------------------------------------------
# Terraform Variable Values - TEMPLATE
# Copy this file to terraform.tfvars and fill in your values
# -------------------------------------------------------

# General
project_name = "multicloud-devops"
environment  = "dev"


# AWS
aws_region     = "ap-southeast-2"
aws_account_id = "587601535321" # Replace with your AWS Account ID

# GCP
gcp_project_id = "multicloud-devops-project" # Replace with your GCP Project ID
gcp_region     = "australia-southeast1"

# Networking
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
availability_zones  = ["ap-southeast-2a", "ap-southeast-2b"]

# Container Platform
ecr_repo_name_a  = "service-a"
ecr_repo_name_b  = "service-b"
ecs_cluster_name = "devops-cluster"
service_a_cpu    = 256
service_a_memory = 512
service_a_port   = 8000
service_b_cpu    = 256
service_b_memory = 512
service_b_port   = 3000
desired_count    = 1

# Autoscaling
autoscaling_min_capacity = 1
autoscaling_max_capacity = 4
cpu_scale_out_threshold  = 70
cpu_scale_in_threshold   = 30

# Notifications
notification_email = "amishasingh2@gmail.com" # Replace with your email

# CI/CD - GitHub source
github_repo             = "singhameesha91/assessment-1-multicloud-devops" # Replace
github_branch           = "main"
codestar_connection_arn = "arn:aws:codeconnections:ap-southeast-2:587601535321:connection/c33a2e00-751f-4019-bdc2-198b69860af8" # Replace after creating CodeStar connection in AWS Console

# State Backend
state_bucket_name     = "multicloud-devops-tfstate"
state_lock_table_name = "terraform-state-lock"

# SAML / Entra ID
saml_metadata_file = "entra-id-metadata.xml"
