provider "aws" {
  region = "ap-south-1"
}

# =========================================================
# VPC
# =========================================================

resource "aws_vpc" "myvpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "myvpc1"
    Environment = "Production"
  }
}


# =========================================================
# PUBLIC SUBNET - AZ 1
# =========================================================

resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1a"
  }
}


# =========================================================
# PUBLIC SUBNET - AZ 2
# =========================================================

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1b"
  }
}


# =========================================================
# INTERNET GATEWAY
# =========================================================

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "myvpc1-igw"
  }
}


# =========================================================
# PUBLIC ROUTE TABLE
# =========================================================

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public-route-table"
  }
}


# =========================================================
# ROUTE TABLE ASSOCIATION - AZ 1
# =========================================================

resource "aws_route_table_association" "public_1a_assoc" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public_rt.id
}


# =========================================================
# ROUTE TABLE ASSOCIATION - AZ 2
# =========================================================

resource "aws_route_table_association" "public_1b_assoc" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public_rt.id
}


# =========================================================
# ALB SECURITY GROUP
# =========================================================

resource "aws_security_group" "alb" {
  name   = "alb-sg"
  vpc_id = aws_vpc.myvpc.id

  # Allow HTTP from the internet
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}


# =========================================================
# EC2 SECURITY GROUP
# =========================================================

resource "aws_security_group" "ec2" {
  name   = "ec2-sg"
  vpc_id = aws_vpc.myvpc.id

  # Only allow HTTP traffic from the ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}


# =========================================================
# APPLICATION LOAD BALANCER
# =========================================================

resource "aws_lb" "app" {
  name               = "my-application-lb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  # IMPORTANT:
  # Both subnets are PUBLIC
  # Both are in different AZs
  subnets = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1b.id
  ]

  tags = {
    Name = "my-application-lb"
  }
}


# =========================================================
# TARGET GROUP
# =========================================================

resource "aws_lb_target_group" "app" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "app-target-group"
  }
}


# =========================================================
# ALB LISTENER
# =========================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}


# =========================================================
# EC2 INSTANCE 1
# =========================================================

resource "aws_instance" "app1" {
  ami           = "ami-090d68841c2a28756"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public_1a.id

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  user_data = <<-EOF
              #!/bin/bash

              yum install -y httpd

              systemctl enable httpd
              systemctl start httpd

              echo "Hello from Server 1" > /var/www/html/index.html
              EOF

  tags = {
    Name = "app-server-1"
  }
}


# =========================================================
# EC2 INSTANCE 2
# =========================================================

resource "aws_instance" "app2" {
  ami           = "ami-090d68841c2a28756"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public_1b.id

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  user_data = <<-EOF
              #!/bin/bash

              yum install -y httpd

              systemctl enable httpd
              systemctl start httpd

              echo "Hello from Server 2" > /var/www/html/index.html
              EOF

  tags = {
    Name = "app-server-2"
  }
}


# =========================================================
# REGISTER EC2 INSTANCE 1 WITH TARGET GROUP
# =========================================================

resource "aws_lb_target_group_attachment" "app1" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app1.id
  port             = 80
}


# =========================================================
# REGISTER EC2 INSTANCE 2 WITH TARGET GROUP
# =========================================================

resource "aws_lb_target_group_attachment" "app2" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app2.id
  port             = 80
}


# =========================================================
# OUTPUT
# =========================================================

output "load_balancer_dns" {
  value = aws_lb.app.dns_name
}
