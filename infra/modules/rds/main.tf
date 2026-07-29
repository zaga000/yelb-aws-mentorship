locals {
  db_ingress_rules = {
    for sg_id in var.var.allowed_security_group_id :
    sg_id => {
      from_port = var.db_port
      to_port   = var.db_port
      source_sg = sg_id
    }
  }
}

resource "aws_security_group" "db" {
  name        = "${var.env}-db-sg"
  description = "Allow DB traffic from specified security groups only"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "db_postgres_ingress" {
  for_each                 = local.db_ingress_rules
  type                     = "ingress"
  security_group_id        = aws_security_group.db.id
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = "tcp"
  source_security_group_id = each.value.source_sg
}

resource "aws_security_group_rule" "db_egress" {
  type              = "egress"
  security_group_id = aws_security_group.db.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}