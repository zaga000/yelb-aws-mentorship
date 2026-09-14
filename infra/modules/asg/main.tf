resource "aws_security_group" "app_sg" {
  name        = "${var.env}-app-sg"
  description = "Allow App traffic from DB servers only"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "app_ingress" {
  type                     = "ingress"
  security_group_id        = aws_security_group.app_sg.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id

}

resource "aws_security_group_rule" "app_egress" {
  type              = "egress"
  security_group_id = aws_security_group.app_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.env}-app-launch-template-"
  image_id      = var.app_ami_id
  instance_type = var.app_instance_type

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance_profile_logs.arn
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    rds_endpoint = var.rds_endpoint
    db_password  = var.db_password
    env          = var.env

  }))
  tags = {
    Name = "${var.env}-app-launch-template"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name             = "${var.env}-app-asg"
  desired_capacity = var.app_desired_capacity
  max_size         = var.app_max_size
  min_size         = var.app_min_size

  vpc_zone_identifier = var.app_subnet_ids

  target_group_arns = [var.target_group_arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.env}-app-asg"
    propagate_at_launch = true
  }

}
resource "aws_iam_role_policy_attachment" "xray_write" {
  role       = aws_iam_role.ec2_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_logs_role" {
  name               = "${var.env}-ec2-logs-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "instance_profile_logs" {
  name = "${var.env}-instance-profile-logs"
  role = aws_iam_role.ec2_logs_role.name
}