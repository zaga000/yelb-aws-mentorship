output "repo_urls" {
    value = {for repo_name, repo in aws_ecr_repository.ecr_repo : repo_name => repo.repository_url }
}