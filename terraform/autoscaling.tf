# -------------------------------------------------------
# Autoscaling - ECS Service scaling policies
# Registers both ECS services as scalable targets and defines
# 4 step-scaling policies (scale-out + scale-in × 2 services).
# Expect: task count scales between min (1) and max (4) based
#         on CloudWatch CPU alarms, with a 60-second cooldown.
# -------------------------------------------------------

# ==================== Scalable Targets ====================
# Registers each ECS service with Application Auto Scaling.
# min=1 ensures at least 1 task is always running.
# max=4 caps costs while allowing burst capacity.

resource "aws_appautoscaling_target" "service_a" {
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service_a.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_target" "service_b" {
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service_b.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# ==================== Service A - Scale Out ====================
# Adds 1 task when the high-CPU alarm fires.
# 60-second cooldown prevents rapid scaling oscillation.

resource "aws_appautoscaling_policy" "service_a_scale_out" {
  name               = "${var.project_name}-${var.environment}-service-a-scale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.service_a.resource_id
  scalable_dimension = aws_appautoscaling_target.service_a.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_a.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment          = 1
      metric_interval_lower_bound = 0
    }
  }
}

# ==================== Service A - Scale In ====================
# Removes 1 task when the low-CPU alarm fires.
# Will not scale below min_capacity (1 task).

resource "aws_appautoscaling_policy" "service_a_scale_in" {
  name               = "${var.project_name}-${var.environment}-service-a-scale-in"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.service_a.resource_id
  scalable_dimension = aws_appautoscaling_target.service_a.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_a.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment          = -1
      metric_interval_upper_bound = 0
    }
  }
}

# ==================== Service B - Scale Out ====================
# Adds 1 task when the high-CPU alarm fires.
# 60-second cooldown prevents rapid scaling oscillation.

resource "aws_appautoscaling_policy" "service_b_scale_out" {
  name               = "${var.project_name}-${var.environment}-service-b-scale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.service_b.resource_id
  scalable_dimension = aws_appautoscaling_target.service_b.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_b.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment          = 1
      metric_interval_lower_bound = 0
    }
  }
}

# ==================== Service B - Scale In ====================
# Removes 1 task when the low-CPU alarm fires.
# Will not scale below min_capacity (1 task).

resource "aws_appautoscaling_policy" "service_b_scale_in" {
  name               = "${var.project_name}-${var.environment}-service-b-scale-in"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.service_b.resource_id
  scalable_dimension = aws_appautoscaling_target.service_b.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_b.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment          = -1
      metric_interval_upper_bound = 0
    }
  }
}
