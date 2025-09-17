variable "role_name" {
  type = string
}

variable "provider_arn" {
  type = string
}

variable "subjects" {
  type = list(string)
}

variable "policy_json" {
  type = string
  default = null
}

variable "managed_policy_arns" {
  type = list(string)
  default = []
}