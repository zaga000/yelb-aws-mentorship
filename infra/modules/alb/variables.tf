variable "env" {
  description = "The deployment environment name (e.g., dev, staging, prod)."
  type        = string
}

variable "cidr_block" {
  type        = list(string)
  description = "The CIDR block for the network"
  default     = ["0.0.0.0/0"]
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}