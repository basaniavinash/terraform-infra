variable "name" {
  type = string
}

variable "cidr" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "azs" {
  type = list(string)
}
