resource "aws_vpc" "myvpc"{
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "myvpc1"
        Environment = "Production"
    }
    
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true

    tags = {
        Name = "public-subnet-1a"
    }
}

resource "aws_subnet" "private"{
    vpc_id=aws_vpc.myvpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "ap-south-1b"

    tags = {
        Name = "private-subnet-1b"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.myvpc.id

    tags = {
        Name = "myvpc1-igw"
    }
}

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

resource "aws_route_table_association" "public_assoc" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public_rt.id

}

resource "aws_security_group" "alb" {
  name   = "alb-sg"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# Load Balancer
# -------------------------
resource "aws_lb" "app" {
  name               = "my-application-lb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public.id,
    aws_subnet.private.id
  ]

  tags = {
    Name = "my-application-lb"
  }
}

# -------------------------
# Target Group
# -------------------------
resource "aws_lb_target_group" "app" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }
}

# -------------------------
# Listener
# -------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"

    target_group_arn = aws_lb_target_group.app.arn
  }
}

# -------------------------
# EC2 Target 1
# -------------------------
resource "aws_instance" "app1" {
  ami           = "ami-090d68841c2a28756"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public.id

  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Hello from Server 1" > /var/www/html/index.html
              EOF

  tags = {
    Name = "app-server-1"
  }
}

# -------------------------
# EC2 Target 2
# -------------------------
resource "aws_instance" "app2" {
  ami           = "ami-090d68841c2a28756"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.private.id

  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Hello from Server 2" > /var/www/html/index.html
              EOF

  tags = {
    Name = "app-server-2"
  }
}

# -------------------------
# Register EC2 instances
# -------------------------
resource "aws_lb_target_group_attachment" "app1" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "app2" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app2.id
  port             = 80
}

# -------------------------
# Output
# -------------------------
output "load_balancer_dns" {
  value = aws_lb.app.dns_name
}