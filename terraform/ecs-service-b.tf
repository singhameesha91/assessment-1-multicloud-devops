# -------------------------------------------------------
# ECS Service B - Task Definition and Service
# Defines how Service B (TypeScript/Bun) runs on Fargate.
# Expect: 1 log group (7-day retention), 1 task definition
#         (256 CPU / 512 MEM), 1 ECS service with CODE_DEPLOY
#         controller for blue/green deployments.
# -------------------------------------------------------

# ==================== CloudWatch Log Group ====================
# Captures stdout/stderr from the container. 7-day retention
# keeps costs low while providing enough history for debugging.

resource "aws_cloudwatch_log_group" "service_b" {
  name              = "/ecs/${var.project_name}-${var.environment}/service-b"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-service-b-logs"
  }
}

# ==================== Task Definition ====================
# Describes the container: image from ECR, port 3000, env vars for
# GCP bucket/project, and CloudWatch logging. Fargate networking
# (awsvpc) gives each task its own ENI and private IP.

resource "aws_ecs_task_definition" "service_b" {
  family                   = "${var.project_name}-${var.environment}-service-b"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.service_b_cpu
  memory                   = var.service_b_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.service_b_task.arn

  container_definitions = jsonencode([
    {
      name      = "service-b"
      image     = "${aws_ecr_repository.service_b.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.service_b_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "PORT", value = tostring(var.service_b_port) },
        { name = "GCP_BUCKET", value = "${var.project_name}-${var.environment}-assets" },
        { name = "GCP_PROJECT", value = var.gcp_project_id },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service_b.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-service-b-task"
  }
}

# ==================== ECS Service ====================
# Maintains the desired count of running tasks and registers them
# with the ALB target group. Uses ECS deployment controller with
# script-managed blue/green deployment via ALB listener swapping.
# lifecycle ignore_changes: prevents Terraform from reverting
# task_definition changes made by the deploy script.

resource "aws_ecs_service" "service_b" {
  name            = "${var.project_name}-${var.environment}-service-b"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service_b.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.service_b.arn
    container_name   = "service-b"
    container_port   = var.service_b_port
  }

  deployment_controller {
    type = "ECS"
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.service_b]

  tags = {
    Name = "${var.project_name}-${var.environment}-service-b"
  }
}
