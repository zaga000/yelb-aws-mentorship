output "vpc_id" {
  value = aws_vpc.main.id
}

output "db_subnet_ids" {
  value = [for subnet in aws_subnet.db_subnet : subnet.id]
}

output "public_subnet_ids" {
  value = [for subnet in aws_subnet.public_subnet : subnet.id]
}

output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private_subnet : subnet.id]
}

output "flow_logs_bucket_name" {
  description = "S3 bucket used for VPC flow logs and load test results"
  value       = aws_s3_bucket.vpc_flow_logs_bucket.bucket
}