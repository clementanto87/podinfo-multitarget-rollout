output "ecr_repository_url" {
  value = aws_ecr_repository.podinfo.repository_url
}

output "terraform_state_bucket" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "terraform_lock_table" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "github_oidc_role_arn" {
  value = aws_iam_role.github_actions_oidc_role.arn
}