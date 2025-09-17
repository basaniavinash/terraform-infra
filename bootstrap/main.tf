terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = "~>5.0"
    }
  }

}

provider "aws" {
  region = var.region
}

#s3 bucket for terraform state
resource "aws_s3_bucket" "tf_state" {
  bucket        = var.tf_state_bucket
  force_destroy = false
  tags          = { "Purpose" : "terraform-state" }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#dynamodb table for state locking
resource "aws_dynamodb_table" "tf_locks" {
  name         = var.tf_lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    "Purpose" = "terraform-locks"
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

#Role for github actions to push to ecr
module "iam_github_ecr" {
  source       = "../modules/iam_github_oidc"
  role_name    = "gha-ecr-push"
  provider_arn = aws_iam_openid_connect_provider.github.arn
  subjects     = var.gha_ecr_subjects
  policy_json = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Resource = "*",
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:DescribeRepositories"
      ]
    }]
  })
}

module "iam_github_terraform" {
  source              = "../modules/iam_github_oidc"
  role_name           = "gha-terraform"
  provider_arn        = aws_iam_openid_connect_provider.github.arn
  subjects            = var.gha_tf_subjects
  managed_policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]
}

output "tf_state_bucket" {
  value = aws_s3_bucket.tf_state.id
}

output "tf_lock_table" {
  value = aws_dynamodb_table.tf_locks.name
}

output "gha_er_push_role_arn" {
  value = module.iam_github_ecr.role_arn
}

output "gha_terraform_role_arn" {
  value = module.iam_github_terraform.role_arn
}

