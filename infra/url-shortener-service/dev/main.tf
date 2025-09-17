data "aws_caller_identity" "current" {}

data "terraform_remote_state" "net" {
  backend = "s3"
  config = {
    bucket         = "bar-tfstate"
    key            = "network/dev/terraform.tfstate"
    region         = var.region
    dynamodb_table = "bar-tf-locks"
  }
}

resource "aws_security_group" "alb" {
  name   = "shortener-dev-alb-sg"
  vpc_id = data.terraform_remote_state.net.outputs.vpc_id
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

resource "aws_lb" "alb" {
  name               = "shortener-dev-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets = [
    data.terraform_remote_state.net.outputs.public_subnet[0],
    data.terraform_remote_state.net.outputs.public_subnet[1]
  ]
}

resource "aws_lb_target_group" "tg" {
  name     = "shortener-dev-tg"
  vpc_id   = data.terraform_remote_state.net.outputs.vpc_id
  protocol = "HTTP"
  port     = 8000
  health_check {
    path                = "/healthz"
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "no targets yet"
      status_code  = "200"
    }
  }
}

resource "aws_security_group" "app" {
  name   = "shortener-dev-app-sg"
  vpc_id = data.terraform_remote_state.net.outputs.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2" {
  name = "shortener-dev-ec2-role"
  assume_role_policy = jsondecode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazon.aws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_ro" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2p" {
  name = "shortener-dev-ec2-profile"
  role = aws_iam_role.ec2.name
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = data.terraform_remote_state.net.outputs.private_subnets != null ? element(data.terraform_remote_state.net.outputs.private_subnets, 0) : null
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2p.name

  user_data = base64encode(
    <<-EOF
      #!/bin/bash
      set -eux
      dnf -update -y || yum update -y docker
      systemctl enable --now docker
      aws ecr get-login-password --region ${var.region} | docker login --username AWS -password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com
      docker run -d --name shortener -p 8000:8000 \
        -e DB_URL="${var.db_url}" \
        -e BASE_URL="http://localhost:8000 \
        ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/url-shortener-service:latest 
    EOF
  )
}

resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.app.id
  port             = 8000
}







