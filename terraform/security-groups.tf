# -------------------------------------------------------
# Security Groups - ALB and ECS Tasks
# Controls network-level access to ALBs and ECS containers.
# Expect: 2 security groups – one for ALBs (public-facing),
#         one for ECS tasks (only reachable from ALB).
# -------------------------------------------------------

# ==================== ALB Security Group ====================
# Allows inbound HTTP (80) and HTTPS (443) from anywhere on the internet.
# All outbound is allowed so the ALB can forward to ECS targets.

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Allow inbound HTTP traffic to ALBs"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_test" {
  security_group_id = aws_security_group.alb.id
  description       = "Test listener for blue/green deployments"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all_out" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ==================== ECS Tasks Security Group ====================
# Only accepts traffic FROM the ALB security group on the service ports.
# This ensures containers are never directly accessible from the internet.
# Outbound is open so tasks can reach DynamoDB, GCS, ECR, and CloudWatch.

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  description = "Allow traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb_a" {
  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "Service A traffic from ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.service_a_port
  to_port                      = var.service_a_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb_b" {
  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "Service B traffic from ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.service_b_port
  to_port                      = var.service_b_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_all_out" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow all outbound (DynamoDB, GCS, ECR, etc.)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
