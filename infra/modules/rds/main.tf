resource "aws_security_group" "db" {
  name        = "${var.env}-db-sg"
  description = "Allow Postgres traffic from App servers only"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "db_postgres_ingress" {
  type                     = "ingress"
  security_group_id        = aws_security_group.db.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.app_security_group_id
}

resource "aws_security_group_rule" "db_egress" {
  type              = "egress"
  security_group_id = aws_security_group.db.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}