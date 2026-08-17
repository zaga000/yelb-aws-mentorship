variable "env" {
  type = string
}
variable "db_port" {
  description = "DB pords (5432 - Postgres, 3306 - MySQL)"
  type        = string
}

variable "allowed_security_group_id" {
  description = "SGs that are allowed to connect to the DB"
}
variable "app_security_group_id" {
  description = "ID of the App Security Group"
  type        = string
}