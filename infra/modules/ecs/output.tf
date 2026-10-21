output "app_sg_id" {
  description = "ID of the SG assigned to the application instances"
  value       = aws_security_group.app.id
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.ecs_cluster.id
}
output "service_discovery_namespace_id" {
  description = "ID of the Cloud Map namespace"
  value       = aws_service_discovery_private_dns_namespace.ecs_service_discovery_namespace.id
}

output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution_role.arn
}

output "capacity_provider_name" {
  value = aws_ecs_capacity_provider.ecs_task_capacity_provider.name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs_cluster.name
}