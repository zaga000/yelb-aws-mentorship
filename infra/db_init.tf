locals {
  db_init_sql = <<-EOT
    CREATE TABLE IF NOT EXISTS restaurants (
      name  varchar(30),
      count integer,
      PRIMARY KEY (name)
    );
    INSERT INTO restaurants (name, count) VALUES
      ('outback', 0), ('bucadibeppo', 0), ('chipotle', 0), ('ihop', 0)
    ON CONFLICT (name) DO NOTHING;
  EOT
}

resource "aws_cloudwatch_log_group" "db_init" {
  name              = "/ecs/${var.env}/db-init"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "db_init" {
  family                   = "${var.env}-db-init"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = module.ecs.ecs_execution_role_arn

  container_definitions = jsonencode([{
    name      = "db-init"
    image     = "postgres:15-alpine"
    memory    = 128
    essential = true
    command   = ["psql", "-v", "ON_ERROR_STOP=1", "-c", local.db_init_sql]

    environment = [
      { name = "PGHOST", value = module.rds.db_address },
      { name = "PGUSER", value = var.db_user },
      { name = "PGPASSWORD", value = var.db_password },
      { name = "PGDATABASE", value = "yelbdatabase" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.db_init.name
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "db-init"
      }
    }
  }])
}