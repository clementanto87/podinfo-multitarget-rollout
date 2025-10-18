provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# ----------------------------
# 1. ECR Repository: podinfo
# ----------------------------
resource "aws_ecr_repository" "podinfo" {
  name = "podinfo"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "podinfo"
  }
}

# ----------------------------
# 2. S3 Bucket for Terraform State
# ----------------------------
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket_name

  tags = {
    Name = "Terraform State Bucket"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ----------------------------
# 3. DynamoDB Table for State Locking
# ----------------------------
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.terraform_state_lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}

# ----------------------------
# 4. IAM OIDC Provider for GitHub
# ----------------------------
data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com/.well-known/jwks"
}

resource "aws_iam_openid_connect_provider" "github_oidc" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint]
}

# ----------------------------
# 5. IAM Role for GitHub Actions (OIDC-based)
# ----------------------------
resource "aws_iam_role" "github_actions_oidc_role" {
  name = "github-actions-oidc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "GitHub Actions OIDC Role"
  }
}

# ----------------------------
# 6. Custom IAM Policy: ECR (Create + Push/Pull podinfo)
# ----------------------------
resource "aws_iam_role_policy" "github_ecr" {
  name = "github-actions-ecr"
  role = aws_iam_role.github_actions_oidc_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:DescribeRepositories",
          "ecr:PutLifecyclePolicy",
          "ecr:SetRepositoryPolicy"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/podinfo"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      }
    ]
  })
}

# ----------------------------
# 7. Custom IAM Policy: S3 (Terraform State Bucket)
# ----------------------------
resource "aws_iam_role_policy" "github_s3" {
  name = "github-actions-s3-tfstate"
  role = aws_iam_role.github_actions_oidc_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      }
    ]
  })
}

# ----------------------------
# 8. Custom IAM Policy: DynamoDB (Terraform Lock Table)
# ----------------------------
resource "aws_iam_role_policy" "github_dynamodb" {
  name = "github-actions-dynamodb-locks"
  role = aws_iam_role.github_actions_oidc_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.terraform_locks.arn
      }
    ]
  })
}