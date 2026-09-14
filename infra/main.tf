module "vpc" {
  source             = "./modules/vpc"
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  create_nat_gateway = var.create_nat_gateway

  public_subnet_count  = var.public_subnet_count
  private_subnet_count = var.private_subnet_count
  db_subnet_count      = var.db_subnet_count
}

module "rds" {
  source                     = "./modules/rds"
  env                        = var.env
  vpc_id                     = module.vpc.vpc_id
  db_subnet_ids              = module.vpc.db_subnet_ids
  app_security_group_id      = module.asg.app_security_group_id
  db_user                    = var.db_user
  db_password                = var.db_password
  db_size                    = var.db_size
  db_port                    = var.db_port
  allowed_security_group_ids = [module.asg.app_security_group_id]
}

module "asg" {
  source               = "./modules/asg"
  vpc_id               = module.vpc.vpc_id
  env                  = var.env
  app_subnet_ids       = module.vpc.private_subnet_ids
  app_instance_type    = var.app_instance_type
  app_ami_id           = var.app_ami_id
  app_desired_capacity = var.app_desired_capacity
  app_max_size         = var.app_max_size
  app_min_size         = var.app_min_size
  db_host              = module.rds.db_address
  rds_endpoint         = module.rds.db_address
  db_password          = var.db_password

  target_group_arn      = module.alb.target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id
}

module "alb" {
  source = "./modules/alb"
  env    = var.env

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

module "observability" {
  source = "./modules/observability"

  env                     = var.env
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  asg_name                = module.asg.asg_name
}
