# Fetch available Availability Zones dynamically
# It will place resources across multiple AZs for high Availability

data "aws_availability_zones" "available" {
  state = "available"
}

# Create custom VPC 
resource "aws_vpc" "production_vpc" {

  # CIDR range for entire VPC
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  # Resource tagging for identification
  tags = {
    Name = "Terra-VPC"
  }
}

# Public Subnet-1 for internet-facing resources
resource "aws_subnet" "web_public_subnet_az1" {
  vpc_id = aws_vpc.production_vpc.id
  # CIDR block for subnet
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet-1 "
  }
}
# Public Subnet-2 in another AZ 
resource "aws_subnet" "web_public_subnet_az2" {

  vpc_id = aws_vpc.production_vpc.id
  # CIDR block for subnet
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet-2"
  }
}

# Private Subnet-1 for backend (or) database resources
resource "aws_subnet" "database_private_subnet_az1" {
  vpc_id = aws_vpc.production_vpc.id
  # CIDR block for subnet
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "Private Subnet-1"
  }
}

# Private Subnet-2 in another AZ
resource "aws_subnet" "database_private_subnet_az2" {

  vpc_id = aws_vpc.production_vpc.id
  # CIDR block for subnet
  cidr_block = "10.0.4.0/24"

  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "Private Subnet-2"
  }
}
# Internet Gateway activates internet access for public subnets
resource "aws_internet_gateway" "production_igw" {
  vpc_id = aws_vpc.production_vpc.id

  tags = {
    Name = "Terra-IGW"
  }
}
# Public Route Table
resource "aws_route_table" "public_route_table" {

  vpc_id = aws_vpc.production_vpc.id

  route {
    # Route all internet traffic
    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.production_igw.id
  }

  tags = {
    Name = "Public-RT"
  }
}

# Associate Public Subnet-1 with Public Route Table
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.web_public_subnet_az1.id
  route_table_id = aws_route_table.public_route_table.id
}
# Private Route Table for backend subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.production_vpc.id
  tags = {
    Name = "Private-RT"
  }
}
# Associate Private Subnet-1 with Private Route Table
resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.database_private_subnet_az1.id
  route_table_id = aws_route_table.private_route_table.id
}

#Security Group Creation
resource "aws_security_group" "terra_sg" {
  name        = "terra-SG"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.production_vpc.id
  tags = {
    Name = "terra-SG"
  }
}

# Security Group for Web Server
resource "aws_security_group" "web_sg" {

  name   = "web-sg"
  vpc_id = aws_vpc.production_vpc.id

  # Allow HTTP traffic from internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Security Group for RDS Database
resource "aws_security_group" "db_sg" {

  name   = "db-sg"
  vpc_id = aws_vpc.production_vpc.id
  # Allow MySQL access only from web servers
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# EC2 Web Server  
resource "aws_instance" "web" {
  # Latest Amazon-Linux 2023 AMI
  ami = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  # Required Instance Type
  instance_type = "t3.micro"

  tags = {
    Name = "Terraform"
  }
  # Launch instance in public subnet
  subnet_id = aws_subnet.web_public_subnet_az1.id

  # Attach web security group
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Enable public IP
  associate_public_ip_address = true

  # Bootstrap script executed during Instance launch
  # Installs Apache and creates webpage
  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install httpd -y
systemctl start httpd
systemctl enable httpd
echo "Welcome to My Web Server" > /var/www/html/index.html
EOF
}
# DB Subnet Group is required for RDS Database deployment
resource "aws_db_subnet_group" "mysql_private_subnet_group" {

  name = "db-subnet-group"

  # Attach private subnets for database deployment
  subnet_ids = [
    aws_subnet.database_private_subnet_az1.id,
    aws_subnet.database_private_subnet_az2.id
  ]

  tags = {
    Name = "db subnet group"
  }
}
# MySQL RDS Database
resource "aws_db_instance" "default" {
  # Storage size in GB
  allocated_storage = 10
  # Database Name
  db_name = "terradb"
  # Database Engine
  engine = "mysql"
  #MySQl Version
  engine_version = "8.0"
  # DB instance size
  instance_class = "db.t3.micro"
  # Master credentials
  username = "admin"
  password = "admin123"
  # Default parameter group
  parameter_group_name = "default.mysql8.0"

  # Skip snapshot during deletion
  skip_final_snapshot = true
  # Attach DB security group
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # Use private subnet group
  db_subnet_group_name = aws_db_subnet_group.mysql_private_subnet_group.name

  # Disable public accessibility for security
  publicly_accessible = false
}

# Application Load Balancer Target Group
resource "aws_lb_target_group" "tg" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.production_vpc.id

  # Health check configuration
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "Web-TG"
  }
}

# Application Load Balancer
resource "aws_lb" "alb" {

  name     = "terra-ALB"
  internal = false
  # Load balancer type
  load_balancer_type = "application"
  # Attach security group
  security_groups = [aws_security_group.web_sg.id]
  # Attach public subnets across AZs
  subnets = [
    aws_subnet.web_public_subnet_az1.id,
    aws_subnet.web_public_subnet_az2.id
  ]
  # Disable deletion protection
  enable_deletion_protection = false

  tags = {
    Name = "Terra-ALB"
  }
}
# Listener for ALB
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  # Forward requests to Target Group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
# Attach EC2 Instance to Target Group
resource "aws_lb_target_group_attachment" "tg_attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web.id
  port             = 80
}