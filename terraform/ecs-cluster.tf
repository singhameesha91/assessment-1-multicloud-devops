# -------------------------------------------------------
# ECS Cluster - Fargate compute platform
# Creates a single ECS cluster that hosts both microservices.
# Expect: 1 Fargate cluster with Container Insights enabled
#         for enhanced monitoring (CPU, memory, network metrics).
# -------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-${var.ecs_cluster_name}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.ecs_cluster_name}"
  }
}
