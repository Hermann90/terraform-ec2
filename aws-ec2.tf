# configured aws provider with proper credentials
provider "aws" {
  region    = var.aws_region
  profile   = "default"
}

# create default vpc if one does not exit
resource "aws_default_vpc" "default_vpc" {

  tags    = {
    Name  = "utrains ec2 vpc"
  }
}

# use data source to get all avalablility zones in region
data "aws_availability_zones" "available_zones" {}

# create default subnet if one does not exit
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags   = {
    Name = "utrains ec2 default subnet"
  }
}

# create security group for the ec2 instance
resource "aws_security_group" "ec2_ec2_security_group" {
  name        = "ec2 ec2 security group"
  description = "allow access on ports 8080 and 22"
  vpc_id      = aws_default_vpc.default_vpc.id

  # allow access on port 22 ssh connection
  ingress {
    description      = "ssh access"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags   = {
    Name = "utrains ec2"
  }
}

# use data source to get a registered amazon linux 2 ami
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

# Generates a secure private key and encodes it as PEM
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
# Create the Key Pair
resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2_key_pair"  
  public_key = tls_private_key.ec2_key.public_key_openssh
}
# Save file
resource "local_file" "ssh_key" {
  filename = "${aws_key_pair.ec2_key.key_name}.pem"
  content  = tls_private_key.ec2_key.private_key_pem
}

# launch the ec2 instance
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.aws_instance_type
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_ec2_security_group.id]
  key_name               = aws_key_pair.ec2_key.key_name
  #user_data            = file("som_installation.sh")
  tags = {
    Name = "ec2 ssh security group"
  }
}

# an empty resource block
resource "null_resource" "name" {

  # ssh into the ec2 instance 
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(local_file.ssh_key.filename)
    host        = aws_instance.ec2_instance.public_ip
  }
  # wait for ec2 to be created
  depends_on = [aws_instance.ec2_instance]
}

# print the url of the ec2 server
output "ssh_connection_command" {
  value     = join ("", ["ssh -i ec2_key_pair.pem ec2-user@", aws_instance.ec2_instance.public_dns])
}