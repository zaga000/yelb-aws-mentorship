output "website_url" {
  description = "URL of the Yelb application"
  value       = "http://${module.alb.alb_dns_name}"
}
output "locust_web_ui" {
  value = module.locust.locust_web_ui_url
}

output "ecr_repo_urls" {
  value = module.ecr.repo_urls
}