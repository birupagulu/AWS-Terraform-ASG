//Take AWS provider with region
provider "aws" {
  region = "us-east-1"
}


// Create a VPC (Virtual Private Cloud) with public and private subnets
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

// Create an Internet Gateway and attach it to the VPC & Route table
resource "aws_internet_gateway" "demo-igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "demo-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo-igw.id
  }

  tags = {
    Name = "route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

// Create Security group with ingress & egress rule
resource "aws_security_group" "web-sg" {
  name_prefix = "web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "egress_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web-sg.id
}

// Create Load balancer with target group & listner port
resource "aws_lb" "demo-lb" {
  name = "demo-lb"
  internal = false
  load_balancer_type = "application"
  subnets = [aws_subnet.public.id, aws_subnet.private.id]
  security_groups = [aws_security_group.web-sg.id]

  tags = {
    Name = "example-lb"
    Environment = "dev"
  }
}

resource "aws_lb_target_group" "lb-tg" {
  name_prefix = "lb-tg"
  port = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id = aws_vpc.main.id
}

resource "aws_lb_listener" "demo-ls" {
  load_balancer_arn = aws_lb.demo-lb.arn
  port = 80
  default_action {
    target_group_arn = aws_lb_target_group.lb-tg.arn
    type = "forward"
  }
}

// Lunch configuration & attach template in auto scaling group
resource "aws_launch_configuration" "demo-LC" {
  image_id        = "ami-007855ac798b5175e"
  instance_type  = "t2.micro"
  key_name = "devs-key"
  security_groups = [aws_security_group.web-sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install apache2 -y
              sudo systemctl start apache2
              sudo echo "<html><body><h1>welcome to Birendra website</h1></body></html>" > /var/www/html/index.html
              EOF
}

resource "aws_autoscaling_group" "demo-asg" {
  name                 = "demo-asg"
  launch_configuration = aws_launch_configuration.demo-LC.id
  vpc_zone_identifier  = [aws_subnet.public.id]
  target_group_arns = [aws_lb_target_group.lb-tg.arn]
  min_size             = 3
  max_size             = 5

  tag {
    key                 = "Name"
    value               = "ASG-EC2-instance"
    propagate_at_launch = true
  }
}

