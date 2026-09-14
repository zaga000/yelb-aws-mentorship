variable "env" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}
variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}
variable "instance_size" {
  description = "EC2 instance size"
  type        = string
}

variable "create_nat_gateway" {
  description = "Wheter to create a NAT Gateway"
  type        = bool
  default     = false
}

variable "public_subnet_count" {
  description = "Number of public subnets to create"
  type        = number
  default     = 2
}
variable "private_subnet_count" {
  description = "Number of private subnets to create"
  type        = number
  default     = 2
}
variable "db_subnet_count" {
  description = "Number of db subnets to create"
  type        = number
  default     = 2
}

variable "db_port" {
  type = number
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type = string
}

variable "db_size" {
  type = string
}
variable "cidr_block" {
  type = string
}
variable "app_instance_type" {
  type        = string
  description = "EC2 instance type for app ASG"
}

variable "nat_eip" {
  type    = string
  default = true
}

variable "app_ami_id" {
  type        = string
  description = "AMI ID for app instances"
}

variable "app_desired_capacity" {
  type        = number
  description = "Desired capacity for app ASG"
}

variable "app_max_size" {
  type        = number
  description = "Max size for app ASG"
}

variable "app_min_size" {
  type        = number
  description = "Min size for app ASG"
}