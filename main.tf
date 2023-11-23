resource "aws_security_group" "security_group" {
  name        = "${var.env}-${var.component}-sg"
  description = "${var.env}-${var.component}-sg"
  vpc_id      = var.vpc_id

  ingress {
    description      = "HTTP"
    from_port        = var.app_port
    to_port          = var.app_port
    protocol         = "tcp"
    cidr_blocks      = [var.vpc_cidr]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.workstation_node_cidr
  }

  ingress {
    description      = "PROMETHEUS"
    from_port        = 9100
    to_port          = 9100
    protocol         = "tcp"
    cidr_blocks      = var.prometheus_cidr
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-${var.component}-sg"
  }
}

resource "aws_iam_role" "role" {
  name = "${var.env}-${var.component}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "${var.env}-${var.component}-policy"

    policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "VisualEditor0",
          "Effect": "Allow",
          "Action": [
            "kms:Decrypt",
            "ssm:DescribeParameters",
            "ssm:GetParameterHistory",
            "ssm:GetParametersByPath",
            "ssm:GetParameters",
            "ssm:GetParameter"
          ],
          "Resource": "*"
        }
      ]
    })
  }

  tags = {
    tag-key = "${var.env}-${var.component}-role"
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.env}-${var.component}-role"
  role = aws_iam_role.role.name
}

resource "aws_launch_template" "template" {
  name                   = "${var.env}-${var.component}"
  image_id               = data.aws_ami.ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.security_group.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 10
      encrypted             = true
      delete_on_termination = true
      kms_key_id            = var.kms_key_id
    }
  }

  user_data   = base64encode(templatefile("${path.module}/userdata.sh", {
    role_name = var.component,
    env       = var.env
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.env}-${var.component}"
    }
  }
 }

resource "aws_autoscaling_group" "asg" {
  name               = "${var.env}-${var.component}"
  desired_capacity   = var.instance_count
  max_size           = var.instance_count + 5
  min_size           = var.instance_count
  vpc_zone_identifier = var.subnets
  target_group_arns = [aws_lb_target_group.tg.arn]

  launch_template {
    id      = aws_launch_template.template.id
    version = "$Latest"
  }
  tag {
    key                 = "project"
    propagate_at_launch = true
    value               = "roboshop"
  }
  tag {
    key                 = "Monitor"
    propagate_at_launch = true
    value               = "true"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.env}-${var.component}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  deregistration_delay = 30
  health_check {
    enabled = true
    healthy_threshold = 2
    interval = 5
    unhealthy_threshold = 2
    port = var.app_port
    path = "/health"
    timeout = 3
  }
}

resource "aws_route53_record" "record" {
  zone_id = var.zone_id
  name    = "${var.component}-${var.env}"
  type    = "CNAME"
  ttl     = 30
  records = [var.alb_dns_name]
}