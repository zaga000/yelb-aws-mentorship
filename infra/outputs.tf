output "website_url" {
  description = "URL of the Yelb application"
  value       = "http://${module.alb.alb_dns_name}"
}