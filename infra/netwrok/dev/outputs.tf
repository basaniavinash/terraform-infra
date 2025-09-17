output "vpc_id" {
  value = aws_vpc.dev.id
}

output "public_subnet" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}
