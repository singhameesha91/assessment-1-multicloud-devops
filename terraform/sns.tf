# -------------------------------------------------------
# SNS Topic - Alarm notifications
# Creates an SNS topic that CloudWatch alarms publish to.
# Expect: 1 topic + optional email subscription.
# When an alarm fires, you receive an email notification.
# Set notification_email in terraform.tfvars to enable.
# -------------------------------------------------------

resource "aws_sns_topic" "notifications" {
  name = "${var.project_name}-${var.environment}-notifications"

  tags = {
    Name = "${var.project_name}-${var.environment}-notifications"
  }
}

# Only created if notification_email is provided in tfvars.
# After apply, AWS sends a confirmation email – you must click
# the link to activate the subscription.
resource "aws_sns_topic_subscription" "email" {
  count = var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
