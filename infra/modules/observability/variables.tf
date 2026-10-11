variable "env" {
  type = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (e.g. app/dev-app-alb/1234567890abcdef)"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group"
  type        = string
}

variable "asg_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
}