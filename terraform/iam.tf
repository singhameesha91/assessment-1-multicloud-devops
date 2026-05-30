# -------------------------------------------------------
# IAM Roles - ECS, CodeBuild, CodePipeline
# Creates 5 IAM roles following least-privilege principles:
#   1. Task Execution Role – ECS agent pulls images & writes logs.
#   2. Service A Task Role – DynamoDB CRUD for transactions table.
#   3. Service B Task Role – minimal (GCS via GCP credentials).
#   4. CodeBuild Role – ECR push, CloudWatch logs, S3 artifacts,
#      ECS/ALB manipulation for blue/green deployments.
#   5. CodePipeline Role – orchestrates Source → Build → Deploy.
# -------------------------------------------------------

# ==================== Data Sources ====================
# Trust policy that allows the ECS service to assume these roles.

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ==================== ECS Task Execution Role ====================
# Used by the ECS agent to pull images from ECR and write logs

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project_name}-${var.environment}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-exec-role"
  }
}

# Attaches the AWS-managed ECS execution policy (ECR pull + CloudWatch logs).
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ==================== Service A Task Role ====================
# Grants DynamoDB access to Service A containers

resource "aws_iam_role" "service_a_task" {
  name               = "${var.project_name}-${var.environment}-service-a-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-service-a-task-role"
  }
}

# Inline policy scoped to only the transactions table ARN.
# Actions match exactly what Service A's FastAPI code uses.
data "aws_iam_policy_document" "service_a_dynamodb" {
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem",
    ]
    resources = [aws_dynamodb_table.transactions.arn]
  }
}

resource "aws_iam_role_policy" "service_a_dynamodb" {
  name   = "dynamodb-access"
  role   = aws_iam_role.service_a_task.id
  policy = data.aws_iam_policy_document.service_a_dynamodb.json
}

# ==================== Service B Task Role ====================
# Minimal role - GCS access happens via GCP credentials, not AWS IAM

resource "aws_iam_role" "service_b_task" {
  name               = "${var.project_name}-${var.environment}-service-b-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-service-b-task-role"
  }
}

# ==================== CodeBuild Role ====================
# Allows CodeBuild to: push images to ECR, write build logs to
# CloudWatch, read/write pipeline artifacts in S3, and manage
# ECS/ALB for blue/green deployments.

data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.project_name}-${var.environment}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-codebuild-role"
  }
}

data "aws_iam_policy_document" "codebuild" {
  # ECR: login, push, and pull images
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [
      aws_ecr_repository.service_a.arn,
      aws_ecr_repository.service_b.arn,
    ]
  }

  # CloudWatch Logs: write build logs
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  # S3: read source artifacts, write build artifacts
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.pipeline_artifacts.arn,
      "${aws_s3_bucket.pipeline_artifacts.arn}/*",
    ]
  }

  # ECS: register task definitions and update services (blue/green deploy)
  statement {
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
    ]
    resources = ["*"]
  }

  # ELB: modify listeners for blue/green traffic switching
  statement {
    actions = [
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:ModifyListener",
    ]
    resources = ["*"]
  }

  # IAM: pass task roles to ECS
  statement {
    actions   = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.service_a_task.arn,
      aws_iam_role.service_b_task.arn,
    ]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "codebuild-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

# ==================== CodePipeline Role ====================
# Allows CodePipeline to: use CodeStar connections (GitHub source),
# trigger CodeBuild, and manage S3 artifacts.

data "aws_iam_policy_document" "codepipeline_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${var.project_name}-${var.environment}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-codepipeline-role"
  }
}

data "aws_iam_policy_document" "codepipeline" {
  # S3: read/write pipeline artifacts
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetBucketVersioning",
    ]
    resources = [
      aws_s3_bucket.pipeline_artifacts.arn,
      "${aws_s3_bucket.pipeline_artifacts.arn}/*",
    ]
  }

  # CodeStar: use GitHub connection for source stage
  dynamic "statement" {
    for_each = var.codestar_connection_arn != "" ? [1] : []
    content {
      actions   = ["codestar-connections:UseConnection"]
      resources = [var.codestar_connection_arn]
    }
  }

  # CodeBuild: trigger builds
  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]
    resources = [
      aws_codebuild_project.service_a.arn,
      aws_codebuild_project.service_b.arn,
      aws_codebuild_project.deploy_service_a.arn,
      aws_codebuild_project.deploy_service_b.arn,
    ]
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "codepipeline-policy"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline.json
}
