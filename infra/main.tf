module "vpc" {
  source             = "./modules/vpc"
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  create_nat_gateway = var.create_nat_gateway

  public_subnet_count  = var.public_subnet_count
  private_subnet_count = var.private_subnet_count
  db_subnet_count      = var.db_subnet_count
}