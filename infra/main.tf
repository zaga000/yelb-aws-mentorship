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
  app_security_group_id      = module.ecs.app_sg_id
  db_user                    = var.db_user
  db_password                = var.db_password
  db_size                    = var.db_size
  db_port                    = var.db_port
  allowed_security_group_ids = [module.ecs.app_sg_id]
}

#module "asg" {
#  source               = "./modules/asg"
#  vpc_id               = module.vpc.vpc_id
#  env                  = var.env
#  app_subnet_ids       = module.vpc.private_subnet_ids
#  app_instance_type    = var.app_instance_type
#  app_ami_id           = var.app_ami_id
#  app_desired_capacity = var.app_desired_capacity
#  app_max_size         = var.app_max_size
#  app_min_size         = var.app_min_size
#  db_host              = module.rds.db_address
#  rds_endpoint         = module.rds.db_address
#  db_password          = var.db_password
#
#  target_group_arn      = module.alb.target_group_arn
#  alb_security_group_id = module.alb.alb_security_group_id
#}

module "alb" {
  source = "./modules/alb"
  env    = var.env

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

#module "observability" {
#  source = "./modules/observability"
#
#  env                     = var.env
#  alb_arn_suffix          = module.alb.alb_arn_suffix
#  target_group_arn_suffix = module.alb.target_group_arn_suffix
#  asg_name                = module.asg.asg_name
#}

module "locust" {
  source = "./modules/locust"

  env                  = var.env
  vpc_id               = module.vpc.vpc_id
  public_subnet_id     = module.vpc.public_subnet_ids[0]
  locust_ami_id        = var.app_ami_id
  locust_instance_type = "t3.micro"
  alb_url              = "http://${module.alb.alb_dns_name}"
  locust_allowed_cidr  = var.locust_allowed_cidr
  results_bucket       = module.vpc.flow_logs_bucket_name
}

module "ecr" {
  source = "./modules/ecr"
}

module "ecs" {
  source = "./modules/ecs"

  env                    = var.env
  vpc_id                 = module.vpc.vpc_id
  app_desired_capacity   = var.app_desired_capacity
  app_max_size           = var.app_max_size
  app_min_size           = var.app_min_size
  app_instance_type      = var.app_instance_type
  app_subnet_ids         = module.vpc.private_subnet_ids
  alb_security_group_id  = module.alb.alb_security_group_id
  ingress_from_alb_ports = [80]
  ingress_internal_ports = [4567, 6379]
}

module "redis_server" {
  source = "./modules/ecs-service"

  env            = var.env
  region         = "us-east-1"
  name           = "redis-server"
  image          = "redis:4.0.2"
  container_port = 6379

  ecs_cluster_name = module.ecs.ecs_cluster_name

  ecs_cluster_id                 = module.ecs.ecs_cluster_id
  capacity_provider_name         = module.ecs.capacity_provider_name
  execution_role_arn             = module.ecs.ecs_execution_role_arn
  service_discovery_namespace_id = module.ecs.service_discovery_namespace_id
  private_subnet_ids             = module.vpc.private_subnet_ids
  app_sg_id                      = module.ecs.app_sg_id
}


module "yelb_appserver" {
  source = "./modules/ecs-service"

  env            = var.env
  region         = "us-east-1"
  name           = "yelb-appserver"
  image          = "${module.ecr.repo_urls["yelb-appserver"]}:${var.appserver_image_tag}"
  container_port = 4567
  memory         = 384

  environment = [
    { name = "RACK_ENV", value = "custom" },
    { name = "REDIS_SERVER_ENDPOINT", value = "redis-server.yelb.local" },
    { name = "YELB_DB_SERVER_ENDPOINT", value = module.rds.db_address },
  ]

  ecs_cluster_name = module.ecs.ecs_cluster_name
  autoscaling = {
    min        = 1
    max        = 3
    cpu_target = 50
  }

  ecs_cluster_id                 = module.ecs.ecs_cluster_id
  capacity_provider_name         = module.ecs.capacity_provider_name
  execution_role_arn             = module.ecs.ecs_execution_role_arn
  service_discovery_namespace_id = module.ecs.service_discovery_namespace_id
  private_subnet_ids             = module.vpc.private_subnet_ids
  app_sg_id                      = module.ecs.app_sg_id
}

module "yelb_ui" {
  source = "./modules/ecs-service"

  env            = var.env
  region         = "us-east-1"
  name           = "yelb-ui"
  image          = "${module.ecr.repo_urls["yelb-ui"]}:${var.ui_image_tag}"
  container_port = 80

  environment = [
    { name = "YELB_APPSERVER_ENDPOINT", value = "http://yelb-appserver.yelb.local:4567" },
  ]

  ecs_cluster_name = module.ecs.ecs_cluster_name
  autoscaling = {
    min        = 1
    max        = 3
    cpu_target = 50
  }

  target_group_arn               = module.alb.target_group_arn
  ecs_cluster_id                 = module.ecs.ecs_cluster_id
  capacity_provider_name         = module.ecs.capacity_provider_name
  execution_role_arn             = module.ecs.ecs_execution_role_arn
  service_discovery_namespace_id = module.ecs.service_discovery_namespace_id
  private_subnet_ids             = module.vpc.private_subnet_ids
  app_sg_id                      = module.ecs.app_sg_id
}