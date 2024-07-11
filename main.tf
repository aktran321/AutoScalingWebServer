provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Subnets
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_3" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_subnet" "private_3" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "us-east-1c"
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.example.id
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_3" {
  subnet_id      = aws_subnet.public_3.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "web" {
  vpc_id = aws_vpc.example.id

  # Allow inbound HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound SSH traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Network ACL
resource "aws_network_acl" "web_acl" {
  vpc_id = aws_vpc.example.id
  subnet_ids = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id,
    aws_subnet.public_3.id,
    aws_subnet.private_1.id,
    aws_subnet.private_2.id,
    aws_subnet.private_3.id
  ]

  # Allow inbound HTTP traffic
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow inbound SSH traffic
  ingress {
    rule_no    = 101
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Allow all inbound traffic
  ingress {
    rule_no    = 102
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow all outbound traffic
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}


# EC2 User Data Script
data "template_file" "userdata" {
  template = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y epel-release
              yum install -y stress
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              echo "Hello World from $(hostname -f)" > /var/www/html/index.html
              # Run stress for 1 minute to simulate high CPU usage
              stress --cpu 4 --timeout 60
            EOF
}


# Launch Configuration
resource "aws_launch_configuration" "web" {
  name          = "web-launch-configuration"
  key_name      = "KHT"
  image_id      = "ami-0b72821e2f351e396" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  security_groups = [aws_security_group.web.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  associate_public_ip_address = true

  user_data = data.template_file.userdata.rendered

  lifecycle {
    create_before_destroy = true
  }
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}


# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  vpc_zone_identifier = [aws_subnet.private_1.id, aws_subnet.private_2.id, aws_subnet.private_3.id]
  launch_configuration = aws_launch_configuration.web.id
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }
}

# Application Load Balancer
resource "aws_lb" "web" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id, aws_subnet.public_3.id]
}

resource "aws_lb_target_group" "web" {
  name        = "web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.example.id
  target_type = "instance"
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.web.name
  lb_target_group_arn   = aws_lb_target_group.web.arn
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name                = "high-cpu-utilization"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "30"
  statistic                 = "Average"
  threshold                 = "75"
  alarm_actions             = [aws_autoscaling_policy.scale_out.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name                = "low-cpu-utilization"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "30"
  statistic                 = "Average"
  threshold                 = "20"
  alarm_actions             = [aws_autoscaling_policy.scale_in.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale_out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale_in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = aws_autoscaling_group.web.name
}

# IAM Role
resource "aws_iam_role" "ssm_role" {
  name = "ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role Policy Attachment
resource "aws_iam_role_policy_attachment" "ssm_role_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
