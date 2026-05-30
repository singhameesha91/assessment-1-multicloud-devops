# -------------------------------------------------------
# CodeBuild Projects - Docker image builders
# Creates 2 CodeBuild projects (one per microservice) that:
#   1. Log in to ECR
#   2. Build the Docker image from the service Dockerfile
#   3. Push the image to ECR with commit hash + latest tags
#   4. Output imagedefinitions JSON for CodeDeploy
# Expect: 2 projects using aws/codebuild/standard:7.0 image
#         with Docker-in-Docker (privileged mode) enabled.
# -------------------------------------------------------

# ==================== Service A CodeBuild ====================
# Builds Python/FastAPI Docker image from services/service-a/.
# Uses buildspec-service-a.yml in the project root.

resource "aws_codebuild_project" "service_a" {
  name          = "${var.project_name}-${var.environment}-build-service-a"
  description   = "Build and push Service A Docker image to ECR"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }

    environment_variable {
      name  = "ECR_REPO_NAME_A"
      value = aws_ecr_repository.service_a.name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-service-a.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${var.project_name}-${var.environment}/service-a"
      stream_name = "build"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-build-service-a"
  }
}

# ==================== Service B CodeBuild ====================
# Builds TypeScript/Bun Docker image from services/service-b/.
# Uses buildspec-service-b.yml in the project root.

resource "aws_codebuild_project" "service_b" {
  name          = "${var.project_name}-${var.environment}-build-service-b"
  description   = "Build and push Service B Docker image to ECR"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }

    environment_variable {
      name  = "ECR_REPO_NAME_B"
      value = aws_ecr_repository.service_b.name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-service-b.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${var.project_name}-${var.environment}/service-b"
      stream_name = "build"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-build-service-b"
  }
}

# ==================== CodeBuild Log Groups ====================
# Explicit log groups so we control retention (7 days to save costs).

resource "aws_cloudwatch_log_group" "codebuild_a" {
  name              = "/codebuild/${var.project_name}-${var.environment}/service-a"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-codebuild-a-logs"
  }
}

resource "aws_cloudwatch_log_group" "codebuild_b" {
  name              = "/codebuild/${var.project_name}-${var.environment}/service-b"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-codebuild-b-logs"
  }
}

# ==================== Deploy CodeBuild Projects ====================
# These projects handle blue/green deployment via ALB listener swapping.
# They register the new task definition, update the ECS service to put
# new tasks on the green target group, wait for health, then swap
# the production listener from blue → green.

resource "aws_codebuild_project" "deploy_service_a" {
  name          = "${var.project_name}-${var.environment}-deploy-service-a"
  description   = "Blue/green deploy Service A via ALB listener swap"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "CLUSTER_NAME"
      value = aws_ecs_cluster.main.name
    }

    environment_variable {
      name  = "SERVICE_NAME"
      value = "${var.project_name}-${var.environment}-service-a"
    }

    environment_variable {
      name  = "TASK_FAMILY"
      value = "${var.project_name}-${var.environment}-service-a"
    }

    environment_variable {
      name  = "CONTAINER_NAME"
      value = "service-a"
    }

    environment_variable {
      name  = "LISTENER_ARN"
      value = aws_lb_listener.service_a.arn
    }

    environment_variable {
      name  = "BLUE_TG_ARN"
      value = aws_lb_target_group.service_a.arn
    }

    environment_variable {
      name  = "GREEN_TG_ARN"
      value = aws_lb_target_group.service_a_green.arn
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-deploy.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${var.project_name}-${var.environment}/deploy-a"
      stream_name = "deploy"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-deploy-service-a"
  }
}

resource "aws_codebuild_project" "deploy_service_b" {
  name          = "${var.project_name}-${var.environment}-deploy-service-b"
  description   = "Blue/green deploy Service B via ALB listener swap"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "CLUSTER_NAME"
      value = aws_ecs_cluster.main.name
    }

    environment_variable {
      name  = "SERVICE_NAME"
      value = "${var.project_name}-${var.environment}-service-b"
    }

    environment_variable {
      name  = "TASK_FAMILY"
      value = "${var.project_name}-${var.environment}-service-b"
    }

    environment_variable {
      name  = "CONTAINER_NAME"
      value = "service-b"
    }

    environment_variable {
      name  = "LISTENER_ARN"
      value = aws_lb_listener.service_b.arn
    }

    environment_variable {
      name  = "BLUE_TG_ARN"
      value = aws_lb_target_group.service_b.arn
    }

    environment_variable {
      name  = "GREEN_TG_ARN"
      value = aws_lb_target_group.service_b_green.arn
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-deploy.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${var.project_name}-${var.environment}/deploy-b"
      stream_name = "deploy"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-deploy-service-b"
  }
}

resource "aws_cloudwatch_log_group" "codebuild_deploy_a" {
  name              = "/codebuild/${var.project_name}-${var.environment}/deploy-a"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-codebuild-deploy-a-logs"
  }
}

resource "aws_cloudwatch_log_group" "codebuild_deploy_b" {
  name              = "/codebuild/${var.project_name}-${var.environment}/deploy-b"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-codebuild-deploy-b-logs"
  }
}
