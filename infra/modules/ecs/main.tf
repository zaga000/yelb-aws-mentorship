locals {
  ingress_from_alb = {
    for port in var.ingress_from_alb_ports :
    "alb-${port}" => {
      from_port = port
      to_port   = port
      source_sg = var.alb_security_group_id
    }
  }

  ingress_internal = {
    for port in var.ingress_internal_ports :
    "internal-${port}" => {
      from_port = port
      to_port   = port
      source_sg = aws_security_group.app.id
    }
  }

  ingress_rules = merge(local.ingress_from_alb, local.ingress_internal)
}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.env}-yelb-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_security_group" "app" {
  name   = "${var.env}-ecs-sg"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "app_ingress" {
  for_each                 = local.ingress_rules
  type                     = "ingress"
  security_group_id        = aws_security_group.app.id
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = "tcp"
  source_security_group_id = each.value.source_sg
}

resource "aws_security_group_rule" "app_egress" {
  type              = "egress"
  security_group_id = aws_security_group.app.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_iam_role" "ecs_instance_role" {
  name               = "${var.env}-ecs-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.env}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role" "ecs_execution_role" {
  name               = "${var.env}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_launch_template" "ecs_task_launch_template" {
  name          = "${var.env}-ecs-task-launch-template"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.app_instance_type

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name = aws_ecs_cluster.ecs_cluster.name
  }))

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_instance_profile.arn
  }

  tags = {
    Name = "${var.env}-ecs-task-launch-template"
  }

  lifecycle {
    create_before_destroy = true
  }


}

resource "aws_autoscaling_group" "ecs_task_asg" {
  name                = "${var.env}-ecs-task-asg"
  desired_capacity    = var.app_desired_capacity
  max_size            = var.app_max_size
  min_size            = var.app_min_size
  vpc_zone_identifier = var.app_subnet_ids
  launch_template {
    id      = aws_launch_template.ecs_task_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_ecs_capacity_provider" "ecs_task_capacity_provider" { #### <<<<<<<< read about
  name = "${var.env}-ecs-task-capacity-provider"
  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_task_asg.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 1000
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs_task_cluster_capacity_providers" {
  cluster_name       = aws_ecs_cluster.ecs_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.ecs_task_capacity_provider.name]
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_task_capacity_provider.name
    weight            = 1
  }

}

resource "aws_service_discovery_private_dns_namespace" "ecs_service_discovery_namespace" {
  name        = "yelb.local"
  description = "Service discovery namespace for yelb"
  vpc         = var.vpc_id

}