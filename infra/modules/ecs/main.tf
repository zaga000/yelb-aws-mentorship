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
  name   = "${var.env}-app-sg"
  vpc_id = module.vpc.vpc_id
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