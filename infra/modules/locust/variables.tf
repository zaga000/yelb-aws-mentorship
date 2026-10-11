variable "env" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where Locust host will be deployed"
}

variable "public_subnet_id" {
  type        = string
  description = "Public subnet for the Locust host"
}

variable "locust_ami_id" {
  type        = string
  description = "AMI ID for the Locust host (Amazon Linux 2023)"
}

variable "locust_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "alb_url" {
  type        = string
  description = "Target ALB URL for the load test (including http://)"
}

variable "locust_allowed_cidr" {
  type        = string
  description = "CIDR allowed to reach the Locust web UI"
}

variable "results_bucket" {
  type        = string
  description = "Existing S3 bucket where Locust CSV results are uploaded"
}

variable "results_prefix" {
  type        = string
  default     = "load-test-results"
  description = "Key prefix inside the bucket for load test results"
}
