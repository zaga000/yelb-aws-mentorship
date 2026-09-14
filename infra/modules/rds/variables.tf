variable "env" {
  type = string
}
variable "db_port" {
  description = "DB port (5432 - Postgres, 3306 - MySQL)"
  type        = number
}

variable "vpc_id" {
  type = string
}
variable "allowed_security_group_ids" {
  description = "SGs that are allowed to connect to the DB"
  type        = list(string)
}
variable "app_security_group_id" {
  description = "ID of the App Security Group"
  type        = string
}

variable "db_size" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type = string
}

variable "db_subnet_ids" {
  type = list(string)
}