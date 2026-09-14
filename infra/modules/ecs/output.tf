output "app_sg_id" {
  description = "ID of the SG assigned to the application instances"
  value       = aws_security_group.app.id
}