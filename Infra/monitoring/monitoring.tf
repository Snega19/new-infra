# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 4.18.0"
#     }
#   }

#   backend "s3" {
#     bucket         	   = "monitoring-bucket-mfopen5g"
#     key              	   = "state/terraform.tfstate1"
#     region         	   = "us-east-1"
#     encrypt        	   = true
#     dynamodb_table = "monitoring-dynamodb"
#   }
# }

provider "aws" {
  region = "us-east-1"
}

# VPC for Monitoring
resource "aws_vpc" "Monitoring-vpc" {
  cidr_block           = "10.2.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Monitoring-vpc"
  }
}


#Public subnet for Monitoring
resource "aws_subnet" "Monitoring-subnet" {
  vpc_id                  = aws_vpc.Monitoring-vpc.id
  cidr_block              = "10.2.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1c"
  tags = {
    Name = "Monitoring-subnet"
  }
}

#Monitoring Internet Gateway 

resource "aws_internet_gateway" "Monitoring-igw" {
  vpc_id = aws_vpc.Monitoring-vpc.id

  tags = {
    Name = "Monitoring-igw"
  }
}


# Route table for Monitoring-igw

resource "aws_route_table" "Monitoring_igw_rt" {
  vpc_id = aws_vpc.Monitoring-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Monitoring-igw.id
  }

  tags = {
    Name = "Monitoring_igw_rt"
  }
}


# Subnet association for Monitoring
resource "aws_route_table_association" "Monitoring-sa" {
  subnet_id      = aws_subnet.Monitoring-subnet.id
  route_table_id = aws_route_table.Monitoring_igw_rt.id
}


# Public security group Monitoring
resource "aws_security_group" "Monitoring_sg" {
  name        = "Monitoring-sg"
  description = "Allow ssh and all traffic"
  vpc_id      = aws_vpc.Monitoring-vpc.id

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
    Name = "Monitoring_sg"
  }
}



resource "aws_key_pair" "monitoring_kp" {
  key_name   = "monitoring_kp"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "monitoring_kp" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "monitoring_kp"
}


# EC2 instance for Monitoring
resource "aws_instance" "monitoring" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.medium"
  # vpc_id                      = aws_vpc.Core-vpc.id
  key_name                    = "monitoring_kp"
  vpc_security_group_ids      = [aws_security_group.Monitoring_sg.id]
  subnet_id                   = aws_subnet.Monitoring-subnet.id
  associate_public_ip_address = true

  connection {
    type        = "ssh"
    host        = aws_instance.monitoring.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }

  provisioner "file" {
    source      = "./monitoring_kp"
    destination = "/home/ubuntu/monitoring_kp"
  }

  #   root_block_device {
  #     volume_size = 25
  #     volume_type = "io1"
  #     iops        = 100
  #   }
  tags = {
    Name = "monitoring"
  }
}

# Null resource for public EC23456789edited
resource "null_resource" "Monitoring-null-res" {
  connection {
    type        = "ssh"
    host        = aws_instance.monitoring.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }
  provisioner "file" {
    source      = "../../Networking/microk8s.sh"
    destination = "/home/ubuntu/microk8s.sh"
  }
  depends_on = [aws_instance.monitoring]
}

# Null resource for public EC23456789edited
resource "null_resource" "Monitoring-null-resource" {
  connection {
    type        = "ssh"
    host        = aws_instance.monitoring.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }
  provisioner "file" {
    source      = "../../Deploy/ran.sh"
    destination = "/home/ubuntu/ran.sh"
  }
  depends_on = [null_resource.Monitoring-null-res]
}

# Null resource for public EC23456789edited
resource "null_resource" "Monitoring-null-res-install" {
  connection {
    type        = "ssh"
    host        = aws_instance.monitoring.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/microk8s.sh",
      "sudo /home/ubuntu/microk8s.sh",
      "chmod +x /home/ubuntu/ran.sh",
      "sudo /home/ubuntu/ran.sh",
    ]
  }
  depends_on = [null_resource.Monitoring-null-resource]
}

# Elastic IP for core
resource "aws_eip" "core-eip" {
  instance = aws_instance.monitoring.id
  depends_on = [null_resource.Monitoring-null-res-install]
}