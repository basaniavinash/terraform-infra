resource "aws_vpc" "dev" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "shared-dev-vpc" }
}

resource "aws_internet_gateway" "dev-igw" {
  vpc_id = aws_vpc.dev.id
  tags   = { Name = "shared-dev-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.dev.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "shared-dev-subnet-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.dev.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "shared-dev-subnet-public-b" }
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.dev.id
  cidr_block              = "10.10.11.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false
  tags                    = { Name = "shared-dev-subnet-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.dev.id
  cidr_block              = "10.10.12.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = false
  tags                    = { Name = "shared-dev-subnet-private-b" }
}

resource "aws_route_table" "dev-rt" {
  vpc_id = aws_vpc.dev.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev-igw.id
  }
  tags = { Name = "shared-dev-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.dev-rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.dev-rt.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public_a.id
  allocation_id = aws_eip.nat.id
  tags = {
    Name = "shared-dev-nat"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.dev.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "shared-dev-private-rt"
  }
}

resource "aws_route_table_association" "private_nat" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}
