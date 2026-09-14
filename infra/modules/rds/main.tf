locals {
  db_ingress_rules = {
    for idx, sg_id in var.allowed_security_group_ids :
    tostring(idx) => {
      from_port = var.db_port
      to_port   = var.db_port
      source_sg = sg_id
    }
  }
}

resource "aws_security_group" "db" {
  name        = "${var.env}-db-sg"
  description = "Allow DB traffic from specified security groups only"
  vpc_id      = var.vpc_id
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

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.env}-db-subnet-group"
  subnet_ids = var.db_subnet_ids
  tags = {
    Name = "${var.env}-db-subnet-group"
  }
}

resource "aws_db_instance" "db_instance" {
  identifier        = "${var.env}-db-instance"
  allocated_storage = 20
  engine            = "postgres"
  engine_version    = "15.17"

  instance_class = var.db_size
  username       = var.db_user
  password       = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db.id]

  skip_final_snapshot = true
  publicly_accessible = false

}