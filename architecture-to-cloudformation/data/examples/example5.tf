provider "aws" {
  region = "us-east-1"
}

# Define Variables
variable "environment_name" {
  description = "Environment name"
  default     = "Production"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  default     = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet 1"
  default     = "10.0.3.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet 2"
  default     = "10.0.4.0/24"
}

variable "db_subnet_1_cidr" {
  description = "CIDR block for database subnet 1"
  default     = "10.0.5.0/24"
}

variable "db_subnet_2_cidr" {
  description = "CIDR block for database subnet 2"
  default     = "10.0.6.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS instance class"
  default     = "db.t3.micro"
}

# KMS Key for Encryption
resource "aws_kms_key" "main" {
  description = "KMS Key for encrypting data"
  policy       = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment_name}-VPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment_name}-IGW"
  }
}

# Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment_name}-PublicSubnet1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = element(data.aws_availability_zones.available.names, 1)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment_name}-PublicSubnet2"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = element(data.aws_availability_zones.available.names, 0)

  tags = {
    Name = "${var.environment_name}-PrivateSubnet1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = element(data.aws_availability_zones.available.names, 1)

  tags = {
    Name = "${var.environment_name}-PrivateSubnet2"
  }
}

resource "aws_subnet" "db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_1_cidr
  availability_zone = element(data.aws_availability_zones.available.names, 0)

  tags = {
    Name = "${var.environment_name}-DBSubnet1"
  }
}

resource "aws_subnet" "db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_2_cidr
  availability_zone = element(data.aws_availability_zones.available.names, 1)

  tags = {
    Name = "${var.environment_name}-DBSubnet2"
  }
}

# NAT Gateway
resource "aws_eip" "nat_1" {
  vpc = true
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.public_1.id

  depends_on = [aws_internet_gateway.main]
}

# Security Groups
resource "aws_security_group" "alb" {
  vpc_id = aws_vpc.main.id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment_name}-ALBSecurityGroup"
  }
}

resource "aws_security_group" "web" {
  vpc_id = aws_vpc.main.id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  tags = {
    Name = "${var.environment_name}-WebServerSecurityGroup"
  }
}

resource "aws_security_group" "db" {
  vpc_id = aws_vpc.main.id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  tags = {
    Name = "${var.environment_name}-DBSecurityGroup"
  }
}

# Application Load Balancer (ALB)
resource "aws_lb" "main" {
  name               = "${var.environment_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups   = [aws_security_group.alb.id]
  subnets           = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = true
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  default_action {
    type             = "fixed-response"
    fixed_response {
      status_code = 200
      content_type = "text/plain"
      message_body = "OK"
    }
  }
}

# Launch Template for EC2 Instances
resource "aws_launch_template" "web" {
  name_prefix   = "${var.environment_name}-webserver"
  image_id      = "ami-0c55b159cbfafe1f0"  # Replace with your own AMI ID
  instance_type = var.instance_type

  user_data = base64encode(<<-EOT
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
  EOT)

  security_group_names = [aws_security_group.web.name]
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  desired_capacity     = 2
  max_size             = 4
  min_size             = 2
  vpc_zone_identifier  = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  launch_template {
    launch_template_id = aws_launch_template.web.id
    version            = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.main.arn]
  health_check_type = "ELB"
  health_check_grace_period = 300
}

# RDS DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name        = "${var.environment_name}-db-subnet-group"
  subnet_ids  = [aws_subnet.db_1.id, aws_subnet.db_2.id]
  description = "RDS DB subnet group"
}

# RDS Instance
resource "aws_db_instance" "main" {
  db_name              = "myapp"
  engine               = "mysql"
  instance_class       = var.db_instance_class
  allocated_storage    = 20
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az             = true
  publicly_accessible  = false
  storage_encrypted    = true
  backup_retention_period = 7
  kms_key_id           = aws_kms_key.main.id
  master_username      = "admin"
  master_password      = "mysecretpassword"  # In real scenarios, use Secrets Manager!
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = join(",", [aws_subnet.public_1.id, aws_subnet.public_2.id])
}

output "private_subnets" {
  value = join(",", [aws_subnet.private_1.id, aws_subnet.private_2.id])
}

output "db_subnets" {
  value = join(",", [aws_subnet.db_1.id, aws_subnet.db_2.id])
}
