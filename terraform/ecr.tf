# -------------------------------------------------------
# ECR Repositories - Container image storage
# Creates 2 private Docker registries (one per microservice).
# Expect: 2 ECR repos with image scanning on push and lifecycle
#         policies that auto-expire old images (keep last 5).
# -------------------------------------------------------

# Service A ECR repo – stores Python/FastAPI Docker images.
# force_delete = true allows terraform destroy to clean up even with images.
# scan_on_push = true runs vulnerability scanning on every pushed image.

resource "aws_ecr_repository" "service_a" {
  name                 = "${var.project_name}-${var.environment}-${var.ecr_repo_name_a}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.ecr_repo_name_a}"
  }
}

# Service B ECR repo – stores TypeScript/Bun Docker images.

resource "aws_ecr_repository" "service_b" {
  name                 = "${var.project_name}-${var.environment}-${var.ecr_repo_name_b}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.ecr_repo_name_b}"
  }
}

# ==================== Lifecycle Policies ====================
# Keep only the last 5 images to save storage costs

resource "aws_ecr_lifecycle_policy" "service_a" {
  repository = aws_ecr_repository.service_a.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "service_b" {
  repository = aws_ecr_repository.service_b.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}
