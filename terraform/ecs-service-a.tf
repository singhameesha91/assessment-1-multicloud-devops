# -------------------------------------------------------
# ECS Service A - Task Definition and Service
# Defines how Service A (Python/FastAPI) runs on Fargate.
# Expect: 1 log group (7-day retention), 1 task definition
#         (256 CPU / 512 MEM), 1 ECS service with CODE_DEPLOY
#         controller for blue/green deployments.
# -------------------------------------------------------

# ==================== CloudWatch Log Group ====================
# Captures stdout/stderr from the container. 7-day retention
# keeps costs low while providing enough history for debugging.

resource "aws_cloudwatch_log_group" "service_a" {
  name              = "/ecs/${var.project_name}-${var.environment}/service-a"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-service-a-logs"
  }
}

# ==================== Task Definition ====================
# Describes the container: image from ECR, port 8000, env vars for
# DynamoDB region/table, and CloudWatch logging. Fargate networking
# (awsvpc) gives each task its own ENI and private IP.

resource "aws_ecs_task_definition" "service_a" {
  family                   = "${var.project_name}-${var.environment}-service-a"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.service_a_cpu
  memory                   = var.service_a_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.service_a_task.arn

  container_definitions = jsonencode([
    {
      name      = "service-a"
      image     = "${aws_ecr_repository.service_a.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.service_a_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "AWS_REGION", value = var.aws_region },
        { name = "DYNAMODB_TABLE", value = aws_dynamodb_table.transactions.name },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service_a.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-service-a-task"
  }
}

# ==================== ECS Service ====================
# Maintains the desired count of running tasks and registers them
# with the ALB target group. Uses ECS deployment controller with
# script-managed blue/green deployment via ALB listener swapping.
# lifecycle ignore_changes: prevents Terraform from reverting
# task_definition changes made by the deploy script.

resource "aws_ecs_service" "service_a" {
  name            = "${var.project_name}-${var.environment}-service-a"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service_a.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.service_a.arn
    container_name   = "service-a"
    container_port   = var.service_a_port
  }

  deployment_controller {
    type = "ECS"
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.service_a]

  tags = {
    Name = "${var.project_name}-${var.environment}-service-a"
  }
}
