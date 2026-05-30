# -------------------------------------------------------
# ALB for Service A - Application Load Balancer
# Creates an internet-facing ALB that distributes HTTP traffic
# to Service A ECS tasks. Includes a second "green" target group
# for blue/green deployments via ALB listener swapping.
# Expect: 1 ALB, 2 target groups (blue + green), 2 listeners
#         (port 80 = production, port 8080 = test/green).
# Access via: http://<alb-dns-name> → forwards to port 8000.
# -------------------------------------------------------

# Internet-facing ALB spanning both public subnets for HA.
resource "aws_lb" "service_a" {
  name               = "${var.project_name}-${var.environment}-alb-a"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-a"
  }
}

# ==================== Target Group (Blue - Primary) ====================
# Registers ECS task IPs. Health check hits /health endpoint.
# Healthy after 2 consecutive 200 responses; unhealthy after 3 failures.

resource "aws_lb_target_group" "service_a" {
  name        = "${var.project_name}-${var.environment}-tg-a"
  port        = var.service_a_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tg-a"
  }
}

# ==================== Listener (Production - Port 80) ====================
# Listens on port 80 (HTTP) and forwards all traffic to the active TG.
# During blue/green deploy, the deploy script switches this to the green TG.

resource "aws_lb_listener" "service_a" {
  load_balancer_arn = aws_lb.service_a.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_a.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}

# ==================== Test Listener (Port 8080) ====================
# Used during blue/green deployment to validate new tasks on the green
# target group before switching production traffic.

resource "aws_lb_listener" "service_a_test" {
  load_balancer_arn = aws_lb.service_a.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_a_green.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}

# ==================== Green Target Group (Blue/Green Deployment) ====================
# Second target group used during blue/green deployments.
# New tasks register here first; once healthy, the deploy script
# shifts the production listener (port 80) from blue → green.

resource "aws_lb_target_group" "service_a_green" {
  name        = "${var.project_name}-${var.environment}-tg-a-green"
  port        = var.service_a_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tg-a-green"
  }
}
