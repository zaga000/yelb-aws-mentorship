locals {
  azs                            = data.aws_availability_zones.available.names
  generated_public_subnet_cidrs  = [for i in range(var.public_subnet_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  generated_private_subnet_cidrs = [for i in range(var.private_subnet_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  generated_db_subnet_cidrs      = [for i in range(var.db_subnet_count) : cidrsubnet(var.vpc_cidr, 8, i + 20)]

  public_subnets = {
    for i, cidr in local.generated_public_subnet_cidrs :
    cidr => local.azs[i % length(local.azs)]
  }

  private_subnets = {
    for i, cidr in local.generated_private_subnet_cidrs :
    cidr => local.azs[i % length(local.azs)]
  }

  db_subnets = {
    for i, cidr in local.generated_db_subnet_cidrs :
    cidr => local.azs[i % length(local.azs)]
  }

}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.env}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-igw"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  count  = var.create_nat_gateway ? 1 : 0

  tags = {
    Name = "${var.env}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.create_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = aws_subnet.public_subnet[0].id
  tags = {
    Name = "${var.env}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_subnet" "public_subnet" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.key
  availability_zone = each.value
  tags = {
    Name = "${var.env}-public-subnet-${each.value}"
  }
}

resource "aws_subnet" "private_subnet" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.key
  availability_zone = each.value
  tags = {
    Name = "${var.env}-private-subnet-${each.value}"
  }
}

resource "aws_subnet" "db_subnet" {
  for_each = local.db_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.key
  availability_zone = each.value
  tags = {
    Name = "${var.env}-db-subnet-${each.value}"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-public-rt"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-private-rt"
  }
}

resource "aws_route_table" "db_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-db-rt"
  }
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "private_route" {
  count = var.create_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route" "db_route" {
  count = var.create_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.db_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route_table_association" "public_rta" {
  for_each = aws_subnet.public_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rta" {
  for_each = aws_subnet.private_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_db_rta" {
  for_each = aws_subnet.db_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db_rt.id
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"

  tags = {
    Name = "${var.env}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint_route_table_association" "s3_endpoint_private_rta" {
  count = length(aws_route_table.private_rt)

  route_table_id  = aws_route_table.private_rt.id
  vpc_endpoint_id = aws_vpc_endpoint.s3_endpoint.id
}

resource "aws_vpc_endpoint_route_table_association" "s3_endpoint_db_rta" {
  count = length(aws_route_table.db_rt)

  route_table_id  = aws_route_table.db_rt.id
  vpc_endpoint_id = aws_vpc_endpoint.s3_endpoint.id
}

resource "aws_s3_bucket" "vpc_flow_logs_bucket" {
  bucket = "${var.env}-vpc-flow-logs-bucket-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

data "aws_caller_identity" "current" {}

resource "aws_flow_log" "vpc_flow_logs" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = aws_s3_bucket.vpc_flow_logs_bucket.arn

  tags = {
    Name = "${var.env}-vpc-flow-logs"
  }
}
