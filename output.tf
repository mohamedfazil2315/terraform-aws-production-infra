# Output VPC-ID after deployment
output "production_vpc_id" {
  value = aws_vpc.production_vpc.id
}

# Output Public Subnet AZ1 ID
output "web_public_subnet_az1" {
  value = aws_subnet.web_public_subnet_az1.id
}

# Output Public Subnet AZ2 ID
output "web_public_subnet_az2" {
  value = aws_subnet.web_public_subnet_az2.id
}

# Output Private Database Subnet AZ1 ID
output "database_private_subnet_az1" {
  value = aws_subnet.database_private_subnet_az1.id
}

# Output Private Database Subnet AZ2 ID
output "database_private_subnet_az2" {
  value = aws_subnet.database_private_subnet_az2.id
}

# Output EC2 Public IP
output "web_server_public_ip" {
  value = aws_instance.web.public_ip
}

# Output RDS Endpoint
output "mysql_rds_endpoint" {
  value = aws_db_instance.default.endpoint
}

# Output ALB DNS Name
output "application_load_balancer_dns" {
  value = aws_lb.alb.dns_name
}