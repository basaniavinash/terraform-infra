variable "region" {
  type    = string
  default = "us-east-1"
}

variable "tf_state_bucket" {
  type    = string
  default = "bar-tfstate"
}

variable "tf_lock_table" {
  type    = string
  default = "bar-tf-locks"
}

variable "gha_ecr_subjects" {
  type    = list(string)
  default = ["repo:bar-private-org/url-shortener-service:ref:refs/head/main"]
}

variable "gha_tf_subjects" {
  type    = list(string)
  default = ["repo:bar-private-org/url-shortener-service:ref:refs/head/main"]
}
