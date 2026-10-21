variable "env" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}
variable "region" {
  description = "AWS Region"
  type        = string
}
variable "name" {
  description = "Name of the ECS service"

  type = string
}
variable "image" {
  description = "Docker image for the ECS service"
  type        = string
}
variable "container_port" {
  description = "Port on which the container listens"
  type        = number
}
variable "cpu" {
  type    = number
  default = 128
}
variable "memory" {
  type    = number
  default = 256
}
variable "desired_count" {
  type    = number
  default = 1
}
variable "environment" {
  type    = list(object({ name = string, value = string }))
  default = []
}
variable "ecs_cluster_id" {
  description = "ID of the ECS cluster where the service will be deployed"
  type        = string
}
variable "capacity_provider_name" {
  description = "Name of the capacity provider for the ECS service"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of the IAM role for ECS task execution"
  type        = string
}


variable "service_discovery_namespace_id" {
  description = "ID of the service discovery namespace for ECS service"
  type        = string
}
variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ECS service"
  type        = list(string)
}
variable "app_sg_id" {
  description = "ID of the security group for the ECS service"
  type        = string
}

variable "target_group_arn" {
  type    = string
  default = null
}

variable "ecs_cluster_name" { type = string }

variable "autoscaling" {
  description = "Service autoscaling settings; null disables autoscaling"
  type = object({
    min        = number
    max        = number
    cpu_target = number
  })
  default = null
}
