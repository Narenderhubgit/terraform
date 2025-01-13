#aws vpc

resource "aws_vpc" "dev-petclinic" {
  cidr_block           = var.cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.envname}-japan"
  }
}

#public-subnets

resource "aws_subnet" "pubsubnet" {
  vpc_id                  = aws_vpc.dev-petclinic.id
  count                   = length(var.azs)
  cidr_block              = element(var.pubsubnets, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.envname}-pubsubnet-${count.index + 1}"
  }
}

# private -subnets

resource "aws_subnet" "privatesubnet" {
  vpc_id            = aws_vpc.dev-petclinic.id
  count             = length(var.azs)
  cidr_block        = element(var.privatesubnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "${var.envname}-privatesubnet-${count.index + 1}"
  }
}

#data-subnets

resource "aws_subnet" "datasubnet" {
  vpc_id            = aws_vpc.dev-petclinic.id
  count             = length(var.azs)
  cidr_block        = element(var.datasubnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "${var.envname}-datasubnet-${count.index + 1}"
  }
}

#internet_gateway

resource "aws_internet_gateway" "Igw" {
  vpc_id = aws_vpc.dev-petclinic.id

  tags = {
    Name = "${var.envname}-Japan-igw"
  }
}

#eip

resource "aws_eip" "NatIp" {
  domain = "vpc"

  tags = {
    Name = "${var.envname}-NatIp"
  }
}

#NAT gateway

resource "aws_nat_gateway" "Nat-gw" {
  allocation_id = aws_eip.NatIp.id
  subnet_id     = aws_subnet.pubsubnet[0].id

  tags = {
    Name = "${var.envname}-Natgw"
  }
}

#route_table

resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.dev-petclinic.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Igw.id
  }

  tags = {
    Name = "${var.envname}-publicroute"
  }
}

#private_route

resource "aws_route_table" "private-route" {
  vpc_id = aws_vpc.dev-petclinic.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.Nat-gw.id
  }

  tags = {
    Name = "${var.envname}-privateroute"
  }
}

#data route

resource "aws_route_table" "data-route" {
  vpc_id = aws_vpc.dev-petclinic.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.Nat-gw.id
  }

  tags = {
    Name = "${var.envname}-dataroute"
  }
}

#route table association

resource "aws_route_table_association" "pubsubassociation" {
  count          = length(var.pubsubnets)
  subnet_id      = element(aws_subnet.pubsubnet.*.id, count.index)
  route_table_id = aws_route_table.public-route.id
}
resource "aws_route_table_association" "prisubassociation" {
  count          = length(var.privatesubnets)
  subnet_id      = element(aws_subnet.privatesubnet.*.id, count.index)
  route_table_id = aws_route_table.private-route.id
}
resource "aws_route_table_association" "datasubassociation" {
  count          = length(var.privatesubnets)
  subnet_id      = element(aws_subnet.datasubnet.*.id, count.index)
  route_table_id = aws_route_table.data-route.id
}


# resource "aws_security_group" "ansible-ec2-sg" {
#   name        = "ansible-ec2-sg"
#   description = "Allow ssh inbound traffic and all outbound traffic"
#   vpc_id      = vpc-0a8ca3d06cb5af7a3

ingress {
  cidr_blocks = ["0.0.0.0/0"]
  from_port   = 22
  protocol    = "tcp"
  to_port     = 22
}
egress {
  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]

}
 tags = {
  Name = "ansible-ec2-sg"
 }
}
#create key pair
resource "aws_key_pair" "ansible-key" {
  key_name   = "ansible"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAdZGwC9xG/fB2v6rMr8zzF42RIOQpK/2NbQ83TAeRsq DELL@DESKTOP-IU2IE2V"
}
#create ec2

resource "aws_instance" "ansible" {
  ami           = "ami-05576a079321f21f8"
  instance_type = "t2.micro"
  key_name = aws_key_pair.ansible-key.id
  subnet_id = "subnet-0a3b823bb6aa3d0aa"
  vpc_security_group_ids = ["${aws_security_group.ansible-ec2-sg.id}"]
  count = 2


  tags = {
    Name = "ansible-ec2"
  }
}