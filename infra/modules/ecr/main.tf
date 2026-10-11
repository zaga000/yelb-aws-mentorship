resource "aws_ecr_repository" "ecr_repo" {
  for_each             = var.ecr_repositories
  name                 = each.value
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = {
    Name = each.value
  }
}


resource "aws_ecr_lifecycle_policy" "ecr_repo_lifecycle_policy" {
  for_each   = aws_ecr_repository.ecr_repo
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}