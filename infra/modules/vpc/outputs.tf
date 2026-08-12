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