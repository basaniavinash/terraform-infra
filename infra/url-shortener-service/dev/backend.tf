terraform {
  backend "s3" {
    bucket         = "bar-tfstate"
    encrypt        = true
    dynamodb_table = "bar-tf-locks"
    key            = "url-shortener-service/dev/terraform.tfstate"
    region         = "us-east-1"
  }
}
