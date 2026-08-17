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