terraform {
  backend "s3" {
    dynamodb_table = "bar-tf-locks"
    bucket         = "bar-tfstate"
    region         = "us-east-1"
    encrypt        = true
    key            = "network/dev/terraform.tfstate"
  }
}
