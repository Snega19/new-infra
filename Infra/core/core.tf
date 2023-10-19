# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 4.18.0"
#     }
#   }

#   backend "s3" {
#     bucket         	   = "core-bucket-mfopen5g"
#     key              	   = "state/terraform.tfstate1"
#     region         	   = "us-east-1"
#     encrypt        	   = true
#     dynamodb_table = "core-dynamodb"
#   }
# }

provider "aws" {
  region = "us-east-1"
}

# VPC for Corenetwork
resource "aws_vpc" "Core-vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Core-vpc12"
  }
}

# Public subnet for core
resource "aws_subnet" "core-subnet" {
  vpc_id                  = aws_vpc.Core-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "core-subnet"
  }
}

# Core Internet Gateway
resource "aws_internet_gateway" "Core-igw" {
  vpc_id = aws_vpc.Core-vpc.id

  tags = {
    Name = "Core-igw"
  }
}

# Route table for Core-igw
resource "aws_route_table" "core_igw_rt" {
  vpc_id = aws_vpc.Core-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Core-igw.id
  }

  tags = {
    Name = "Core_igw_rt"
  }
}

# Subnet association for Core
resource "aws_route_table_association" "Core-sa" {
  subnet_id      = aws_subnet.core-subnet.id
  route_table_id = aws_route_table.core_igw_rt.id
}

# Public security group
resource "aws_security_group" "Core_sg" {
  name        = "public-sg"
  description = "Allow SSH and all traffic"
  vpc_id      = aws_vpc.Core-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Core_sg"
  }
}

resource "aws_key_pair" "core_kp" {
  key_name   = "core_kp"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "core_kp" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "core_kp"
}

# EC2 instance for core-ec2
resource "aws_instance" "core-ec2" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t3.medium"
  key_name      = "core_kp"
  vpc_security_group_ids      = [aws_security_group.Core_sg.id]
  subnet_id                   = aws_subnet.core-subnet.id
  associate_public_ip_address = true

  connection {
    type        = "ssh"
    host        = aws_instance.core-ec2.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }

  provisioner "file" {
    source      = "./core_kp"
    destination = "/home/ubuntu/core_kp"
  }

  root_block_device {
    volume_size = 25
    volume_type = "io1"
    iops        = 100
  }

  tags = {
    Name = "Core-ec2"
  }
}


# Null resourece file microk8s
resource "null_resource" "Core-null-res" {
  connection {
    type        = "ssh"
    host        = aws_instance.core-ec2.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }

  provisioner "file" {
    source      = "../../Networking/microk8s.sh"
    destination = "/home/ubuntu/microk8s.sh"
  }

  depends_on = [aws_instance.core-ec2]
}

resource "null_resource" "Core-null-resource" {
  connection {
    type        = "ssh"
    host        = aws_instance.core-ec2.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }

  provisioner "file" {
    source      = "../../Deploy/core.sh"
    destination = "/home/ubuntu/core.sh"
  }

  depends_on = [null_resource.Core-null-res]
}


# Null resource for public EC2
resource "null_resource" "Core-null-resourcemic" {
  connection {
    type        = "ssh"
    host        = aws_instance.core-ec2.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "chmod +x /home/ubuntu/microk8s.sh",
      "sudo /home/ubuntu/microk8s.sh",
    ]
  }

  depends_on = [null_resource.Core-null-resource]
}

# Null resource for public EC2
resource "null_resource" "Core-null-resourcecore" {
  connection {
    type        = "ssh"
    host        = aws_instance.core-ec2.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "chmod +x /home/ubuntu/core.sh",
      "sudo /home/ubuntu/core.sh",
    ]
  }

  depends_on = [null_resource.Core-null-resourcemic]
}

# Elastic IP for core
resource "aws_eip" "core-eip" {
  instance = aws_instance.core-ec2.id
  depends_on = [null_resource.Core-null-resourcecore]
}