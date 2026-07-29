output "alb_sg_id" {
  description = "The ID of the Security Group assigned to the Application Load Balancer"
  value       = aws_security_group.alb.id
}