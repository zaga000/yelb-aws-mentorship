locals {
  ingress_from_alb = {
    for port in var.var.ingress_from_alb_ports :
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

resource "aws_security_group" "app" {
  name        = "${var.env}-app-sg"
  description = "Allow traffic from ALB and internal Redis"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "app_http_from_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.app.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
}

resource "aws_security_group_rule" "app_custom_from_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.app.id
  from_port                = 4567
  to_port                  = 4567
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
}

resource "aws_security_group_rule" "app_redis_internal" {
  type                     = "ingress"
  security_group_id        = aws_security_group.app.id
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
}

resource "aws_security_group_rule" "app_egress" {
  type              = "egress"
  security_group_id = aws_security_group.app.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}