variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type        = set(string)
  default     = ["yelb-ui", "yelb-appserver"]
}