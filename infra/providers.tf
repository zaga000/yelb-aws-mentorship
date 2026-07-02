provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.env
      Project     = "yelb-mentorship"
      Owner       = "azahorodn"
      ManagedBy   = "terraform"
    }
  }
}