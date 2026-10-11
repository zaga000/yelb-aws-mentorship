output "locust_public_ip" {
  value = aws_instance.locust.public_ip
}

output "locust_web_ui_url" {
  value = "http://${aws_instance.locust.public_ip}:8089"
}