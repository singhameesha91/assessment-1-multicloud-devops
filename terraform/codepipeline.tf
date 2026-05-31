# -------------------------------------------------------
# CodePipeline - CI/CD orchestrator
# Creates a single pipeline with 3 stages:
#   1. Source  – pulls code from GitHub (via CodeStar connection)
#   2. Build   – parallel CodeBuild for Service A & B (Docker images)
#   3. Deploy  – parallel CodeBuild blue/green deploy for both services
#                (registers new task def, updates ECS, swaps ALB listener)
# Expect: On every push to the configured branch, the pipeline
#         automatically builds new Docker images, pushes to ECR,
#         and performs blue/green deployments to ECS via ALB swap.
# Prerequisites: Create a CodeStar connection to GitHub in the
#                AWS Console and provide its ARN in tfvars.
# -------------------------------------------------------

resource "aws_codepipeline" "main" {
  count    = var.codestar_connection_arn != "" ? 1 : 0
  name     = "${var.project_name}-${var.environment}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.id
    type     = "S3"
  }

  # ==================== Stage 1: Source ====================
  # Pulls source code from GitHub using a CodeStar connection.
  # Triggers automatically on push to the configured branch.
  stage {
    name = "Source"

    action {
      name             = "GitHub-Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = var.github_repo
        BranchName       = var.github_branch
      }
    }
  }

  # ==================== Stage 2: Build ====================
  # Runs both CodeBuild projects in parallel.
  # Each builds a Docker image and pushes it to its ECR repo.
  stage {
    name = "Build"

    action {
      name             = "Build-Service-A"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output_a"]
      run_order        = 1

      configuration = {
        ProjectName = aws_codebuild_project.service_a.name
      }
    }

    action {
      name             = "Build-Service-B"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output_b"]
      run_order        = 1

      configuration = {
        ProjectName = aws_codebuild_project.service_b.name
      }
    }
  }

  # ==================== Stage 3: Deploy ====================
  # Runs both blue/green deployments in parallel via CodeBuild.
  # Each deploy project: registers new task def → updates ECS service
  # → waits for healthy tasks on green TG → swaps ALB listener.
  stage {
    name = "Deploy"

    action {
      name            = "Deploy-Service-A"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output", "build_output_a"]
      run_order       = 1

      configuration = {
        ProjectName   = aws_codebuild_project.deploy_service_a.name
        PrimarySource = "source_output"
      }
    }

    action {
      name            = "Deploy-Service-B"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output", "build_output_b"]
      run_order       = 1

      configuration = {
        ProjectName   = aws_codebuild_project.deploy_service_b.name
        PrimarySource = "source_output"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-pipeline"
  }
}
