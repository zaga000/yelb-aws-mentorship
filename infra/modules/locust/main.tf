resource "aws_security_group" "locust_sg" {
  name        = "${var.env}-locust-sg"
  description = "Locust load generator host"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "locust_web_ui" {
  type              = "ingress"
  security_group_id = aws_security_group.locust_sg.id
  from_port         = 8089
  to_port           = 8089
  protocol          = "tcp"
  cidr_blocks       = [var.locust_allowed_cidr]
}

resource "aws_security_group_rule" "locust_egress" {
  type              = "egress"
  security_group_id = aws_security_group.locust_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

data "aws_iam_policy_document" "locust_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "locust_role" {
  name               = "${var.env}-locust-role"
  assume_role_policy = data.aws_iam_policy_document.locust_assume_role.json
}

resource "aws_iam_role_policy_attachment" "locust_ssm" {
  role       = aws_iam_role.locust_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "locust_s3_write" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.results_bucket}/${var.results_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "locust_s3" {
  name   = "${var.env}-locust-s3-write"
  role   = aws_iam_role.locust_role.id
  policy = data.aws_iam_policy_document.locust_s3_write.json
}

resource "aws_iam_instance_profile" "locust_profile" {
  name = "${var.env}-locust-instance-profile"
  role = aws_iam_role.locust_role.name
}

resource "aws_instance" "locust" {
  ami                         = var.locust_ami_id
  instance_type               = var.locust_instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.locust_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.locust_profile.name

  user_data_base64 = base64encode(templatefile("${path.module}/user_data.sh", {
    alb_url        = var.alb_url
    results_bucket = var.results_bucket
    results_prefix = var.results_prefix
    env            = var.env
  }))
  user_data_replace_on_change = true

  tags = {
    Name = "${var.env}-locust-host"
  }
}