# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 4.18.0"
#     }
#   }

#   backend "s3" {
#     bucket         	   = "ran-bucket-mfopen5g"
#     key              	   = "state/terraform.tfstate1"
#     region         	   = "us-east-1"
#     encrypt        	   = true
#     dynamodb_table = "ran-dynamodb"
#   }
# }

provider "aws" {
  region = "us-east-1"
}


# VPC for RAN1
resource "aws_vpc" "RAN-vpc" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "RAN-vpc"
  }
}

#Public subnet for RAN
resource "aws_subnet" "RAN-subnet" {
  vpc_id                  = aws_vpc.RAN-vpc.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = {
    Name = "RAN-subnet"
  }
}


#RAN Internet Gateway 

resource "aws_internet_gateway" "RAN-igw" {
  vpc_id = aws_vpc.RAN-vpc.id

  tags = {
    Name = "RAN-igw"
  }
}

# Route table for RAN-igw

resource "aws_route_table" "RAN_igw_rt" {
  vpc_id = aws_vpc.RAN-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.RAN-igw.id
  }

  tags = {
    Name = "RAN_igw_rt"
  }
}


# Subnet association for RAN
resource "aws_route_table_association" "RAN-sa" {
  subnet_id      = aws_subnet.RAN-subnet.id
  route_table_id = aws_route_table.RAN_igw_rt.id
}

# Public security group RAN
resource "aws_security_group" "RAN_sg" {
  name        = "RAN-sg"
  description = "Allow ssh and all traffic"
  vpc_id      = aws_vpc.RAN-vpc.id

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
    Name = "RAN_sg"
  }
}


resource "aws_key_pair" "ran_kp" {
  key_name   = "ran_kp"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "ran_kp" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "ran_kp"
}

# EC2 instance for RAN
resource "aws_instance" "RAN-ec2" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.medium"
  # vpc_id                      = aws_vpc.Core-vpc.id
  key_name                    = "ran_kp"
  vpc_security_group_ids      = [aws_security_group.RAN_sg.id]
  subnet_id                   = aws_subnet.RAN-subnet.id
  associate_public_ip_address = true

  connection {
    type        = "ssh"
    host        = aws_instance.RAN-ec2.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }

  provisioner "file" {
    source      = "./ran_kp"
    destination = "/home/ubuntu/ran_kp"
  }

    root_block_device {
      volume_size = 25
      volume_type = "io1"
      iops        = 100
    }
  tags = {
    Name = "RAN-ec2"
  }
}

# Null resource for public EC2
resource "null_resource" "RAN-null-res" {
  connection {
    type        = "ssh"
    host        = aws_instance.RAN-ec2.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }

  provisioner "file" {
    source      = "../../Networking/microk8s.sh"
    destination = "/home/ubuntu/microk8s.sh"
  }
  depends_on = [aws_instance.RAN-ec2]
}

resource "null_resource" "RAN-null-resource" {
  connection {
    type        = "ssh"
    host        = aws_instance.RAN-ec2.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }

  provisioner "file" {
    source      = "../../Deploy/ran.sh"
    destination = "/home/ubuntu/ran.sh"
  }
  depends_on = [null_resource.RAN-null-res]
}

resource "null_resource" "RAN-null-res-ins" {
  connection {
    type        = "ssh"
    host        = aws_instance.RAN-ec2.public_ip
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
  depends_on = [null_resource.RAN-null-resource]
}

# Elastic IP for core
resource "aws_eip" "core-eip" {
  instance = aws_instance.RAN-ec2.id
  depends_on = [null_resource.RAN-null-res-ins]
}

