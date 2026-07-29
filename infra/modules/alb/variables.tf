variable "env" {
  description = "The deployment environment name (e.g., dev, staging, prod)."
  type        = string
}

variable "cidr_block" {
  type        = string
  description = "The CIDR block for the network"
  default     = "0.0.0.0/0"
}