output "alb_sg_id" {
  description = "The ID of the Security Group assigned to the Application Load Balancer"
  value       = aws_security_group.alb_sg.id
}

output "target_group_arn" {
  description = "ARN of the Target Group to attach to ASG"
  value       = aws_lb_target_group.app_tg.arn
}

output "alb_security_group_id" {
  description = "Security Group ID of the ALB"
  value       = aws_security_group.alb_sg.id
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer (Your website URL!)"
  value       = aws_lb.app_alb.dns_name
}