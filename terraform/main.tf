provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "network-vpc" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = false
  instance_tenancy                 = "default"
  enable_dns_hostnames             = true
  enable_dns_support               = true

  tags = {
    Name = "MyVPC"
  }

}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.network-vpc.id
  tags = {
    Name = "cost-free-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.network-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "my-public-subnet-${data.aws_availability_zones.available.names[0]}"
    Type = "Public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.network-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "my-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source to get the VPC by name
data "aws_vpc" "nextwork_vpc" {
  filter {
    name   = "tag:Name"
    values = ["MyVPC"]
  }
}

# Data source to get the public subnet
data "aws_subnet" "public_subnet" {
  vpc_id = data.aws_vpc.nextwork_vpc.id
  filter {
    name   = "tag:Type"
    values = ["Public"]
  }
}

data "aws_route_table" "existing_rt" {
  vpc_id = data.aws_vpc.nextwork_vpc.id
  filter {

    name   = "tag:Name"
    values = ["my-route-table"]  # Update this to match your route table name
  }
}

# Create security group for the EC2 instance
resource "aws_security_group" "ec2_sg" {
  name_prefix = "ec2-sg-"
  description = "Security group for EC2 instance"
  vpc_id      = data.aws_vpc.nextwork_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow outbound traffic (for updates, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-security-group"
  }
}

resource "aws_security_group" "vpc_endpoint_sg" {
  name_prefix = "vpc-endpoint-sg-"
  description = "Security group for VPC endpoints"
  vpc_id      = data.aws_vpc.nextwork_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.nextwork_vpc.cidr_block]
    description = "HTTPS access from VPC"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.nextwork_vpc.cidr_block]
    description = "HTTP access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpc-endpoint-security-group"
  }
}

# Create EC2 instance
resource "aws_instance" "my-ec2" {
  # Amazon Linux 2023 AMI
  ami = data.aws_ami.amazon_linux_2023.id

  # t2.micro instance type (free tier eligible)
  instance_type = "t2.micro"

  # No key pair (not recommended but as requested)
  key_name = "taskapp-key"

  # Network settings
  subnet_id                   = data.aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true  # Auto-assign public IP enabled

  tags = {
    Name = "my-ec2-instance"
  }
}

#launch the S3 bucket

resource "aws_s3_bucket" "my-s3-bucket" {
  bucket = "my-vpc-endpoint-2025-dips"
  tags = {
    Name = "my-S3-bucket"
  }
}


resource "aws_vpc_endpoint" "s3" {
  vpc_id              = data.aws_vpc.nextwork_vpc.id
  service_name        = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type   = "Gateway"
  route_table_ids     = [data.aws_route_table.existing_rt.id]
  policy              = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:ListAllMyBuckets"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "s3-gateway-endpoint"
  }
}

# DynamoDB Gateway Endpoint (Free - no hourly charges)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id              = data.aws_vpc.nextwork_vpc.id
  service_name        = "com.amazonaws.us-east-1.dynamodb"
  vpc_endpoint_type   = "Gateway"
  route_table_ids     = [data.aws_route_table.existing_rt.id]
  policy              = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "dynamodb-gateway-endpoint"
  }
}
