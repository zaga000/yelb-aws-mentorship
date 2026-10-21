variable "env" {
  type = string
}
variable "alb_security_group_id" {
  description = "ID of the ALB Security Group"
  type        = string
}

variable "ingress_from_alb_ports" {
  description = "Ports accessible only from ALB (UI: 80, appserver: 4567)"
  type        = list(number)
  default     = []
}

variable "ingress_internal_ports" {
  description = "Ports accessible only in SG (redis: 6379)"
  type        = list(number)
  default     = []
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

variable "app_instance_type" {
  description = "Instance type for the ECS tasks"
  type        = string
}

variable "app_desired_capacity" {
  description = "Desired capacity for the ECS tasks"
  type        = number
}

variable "app_max_size" {
  description = "Maximum size for the ECS tasks"
  type        = number
}
variable "app_min_size" {
  description = "Minimum size for the ECS tasks"
  type        = number
}
variable "app_subnet_ids" {
  description = "List of subnet IDs for the ECS tasks"
  type        = list(string)
}

variable "autoscaling" {
  description = "Service autoscaling settings; null disables autoscaling"
  type = object({
    min        = number
    max        = number
    cpu_target = number
  })
  default = null
}