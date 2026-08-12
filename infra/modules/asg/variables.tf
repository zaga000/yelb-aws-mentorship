variable "env" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "app_ami_id" {
  description = "AMI ID for the application instances"
  type        = string
}

variable "app_instance_type" {
  description = "Instance type for the application instances"
  type        = string
}

#variable "app_security_group_id" {
#    description = "ID of the App Security Group"
#    type = string
#}

variable "app_subnet_ids" {
  description = "List of Subnet IDs for the application instances"
  type        = list(string)
}

variable "app_desired_capacity" {
  description = "Desired capacity of the ASG Group"
  type        = number
  default     = 2
}

variable "app_max_size" {
  description = "Maximum size of the ASG Group"
  type        = number
  default     = 2
}

variable "app_min_size" {
  description = "Minimum size of the ASG Group"
  type        = number
  default     = 2
}

variable "vpc_id" {
  description = "VPC id where the ASG will be deployed"
  type        = string
}

variable "db_host" { type = string }

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB"
  type        = string
}

variable "db_password" {}

variable "rds_endpoint" {}