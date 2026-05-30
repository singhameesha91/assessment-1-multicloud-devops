# -------------------------------------------------------
# VPC, Subnets, Internet Gateway, Route Tables
# Creates the foundational network layer for all AWS resources.
# Expect: 1 VPC, 2 public subnets (one per AZ), 1 IGW,
#         1 route table with a default route to the IGW.
# -------------------------------------------------------

# ==================== VPC ====================
# Creates an isolated virtual network (10.0.0.0/16 = 65,536 IPs).
# DNS support is enabled so ECS tasks and ALBs can resolve hostnames.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# ==================== Public Subnets ====================
# Creates 2 subnets across different Availability Zones for high availability.
# map_public_ip_on_launch = true so Fargate tasks get public IPs for
# outbound internet access (ECR pulls, DynamoDB, GCS API calls).

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
  }
}

# ==================== Internet Gateway ====================
# Attaches to the VPC to allow inbound traffic from the internet
# (ALB listeners) and outbound traffic from public subnets.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# ==================== Route Table ====================
# Routes all non-local traffic (0.0.0.0/0) through the IGW.
# This makes the subnets "public" – required for ALB and Fargate.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

# ==================== Route Table Associations ====================
# Associates each public subnet with the public route table so they
# inherit the 0.0.0.0/0 → IGW route.

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
