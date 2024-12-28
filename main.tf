#main.tf
provider "aws" {

region = "us-east-1"

shared_credentials_files =  ["~/.aws/credentials"]

}

resource "tls_private_key" "mykey" {
  algorithm = "RSA"

}

resource "aws_key_pair" "aws_key" {
  key_name   = "web-key"
  public_key = tls_private_key.mykey.public_key_openssh

  provisioner "local-exec" {
  command = "echo '${tls_private_key.mykey.private_key_openssh}' > ./web-key.pem"

}

}

resource "aws_vpc" "sl-vpc" {
 cidr_block = "10.0.0.0/16"
  tags = {
   Name = "sl-vpc"
}

}

resource "aws_subnet" "subnet-1"{

vpc_id = aws_vpc.sl-vpc.id
cidr_block = "10.0.1.0/24"
depends_on = [aws_vpc.sl-vpc]
map_public_ip_on_launch = true
  tags = {
   Name = "sl-subnet"
}

}


resource "aws_route_table" "sl-route-table"{
vpc_id = aws_vpc.sl-vpc.id
  tags = {
   Name = "sl-route-table"
}

}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.sl-route-table.id
}


resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.sl-vpc.id
 depends_on = [aws_vpc.sl-vpc]
   tags = {
   Name = "sl-gw"
}

}

resource "aws_route" "sl-route" {

route_table_id = aws_route_table.sl-route-table.id
destination_cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.gw.id


}

variable "sg_ports" {
type = list(number)
default = [8080,80,22,443]

}



resource "aws_security_group" "sl-sg" {
  name        = "sg_rule"
  vpc_id = aws_vpc.sl-vpc.id
  dynamic  "ingress" {
    for_each = var.sg_ports
    iterator = port
    content{
    from_port        = port.value
    to_port          = port.value
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    }
  }
egress {

    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]


}
}

resource "aws_instance" "myec2" {
  ami           = "ami-005fc0f236362e99f"
  instance_type = "t2.medium"
  key_name = "web-key"
  subnet_id = aws_subnet.subnet-1.id
  security_groups = [aws_security_group.sl-sg.id]
  tags = {
    Name = "Project-EC2"
  }
  provisioner "remote-exec" {
  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = tls_private_key.mykey.private_key_pem
    host     = self.public_ip
  }
  inline = [
  "sudo apt update",
  "sudo apt install software-properties-common",
  "sudo add-apt-repository --yes --update ppa:ansible/ansible",
  "sudo apt install ansible -y"
]
}
}
