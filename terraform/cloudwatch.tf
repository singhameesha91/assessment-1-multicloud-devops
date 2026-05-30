# -------------------------------------------------------
# CloudWatch Alarms - CPU utilisation for ECS services
# Creates 4 alarms total (high + low CPU × 2 services).
# Each alarm evaluates over 2 consecutive 60-second periods.
# High CPU alarms trigger scale-out + SNS notification.
# Low CPU alarms trigger scale-in + SNS notification.
# -------------------------------------------------------

# ==================== Service A - High CPU ====================
# Fires when avg CPU >= 70% (default) for 2 minutes.
# Action: adds 1 ECS task and notifies via SNS email.

resource "aws_cloudwatch_metric_alarm" "service_a_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-service-a-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_scale_out_threshold
  alarm_description   = "Service A CPU >= ${var.cpu_scale_out_threshold}% – trigger scale-out"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.service_a.name
  }

  alarm_actions = [
    aws_appautoscaling_policy.service_a_scale_out.arn,
    aws_sns_topic.notifications.arn,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-service-a-cpu-high"
  }
}

# ==================== Service A - Low CPU ====================
# Fires when avg CPU <= 30% (default) for 2 minutes.
# Action: removes 1 ECS task and notifies via SNS email.

resource "aws_cloudwatch_metric_alarm" "service_a_cpu_low" {
  alarm_name          = "${var.project_name}-${var.environment}-service-a-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_scale_in_threshold
  alarm_description   = "Service A CPU <= ${var.cpu_scale_in_threshold}% – trigger scale-in"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.service_a.name
  }

  alarm_actions = [
    aws_appautoscaling_policy.service_a_scale_in.arn,
    aws_sns_topic.notifications.arn,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-service-a-cpu-low"
  }
}

# ==================== Service B - High CPU ====================
# Fires when avg CPU >= 70% (default) for 2 minutes.
# Action: adds 1 ECS task and notifies via SNS email.

resource "aws_cloudwatch_metric_alarm" "service_b_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-service-b-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_scale_out_threshold
  alarm_description   = "Service B CPU >= ${var.cpu_scale_out_threshold}% – trigger scale-out"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.service_b.name
  }

  alarm_actions = [
    aws_appautoscaling_policy.service_b_scale_out.arn,
    aws_sns_topic.notifications.arn,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-service-b-cpu-high"
  }
}

# ==================== Service B - Low CPU ====================
# Fires when avg CPU <= 30% (default) for 2 minutes.
# Action: removes 1 ECS task and notifies via SNS email.

resource "aws_cloudwatch_metric_alarm" "service_b_cpu_low" {
  alarm_name          = "${var.project_name}-${var.environment}-service-b-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_scale_in_threshold
  alarm_description   = "Service B CPU <= ${var.cpu_scale_in_threshold}% – trigger scale-in"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.service_b.name
  }

  alarm_actions = [
    aws_appautoscaling_policy.service_b_scale_in.arn,
    aws_sns_topic.notifications.arn,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-service-b-cpu-low"
  }
}
