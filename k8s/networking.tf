resource "aws_vpc" "k8s" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "k8s"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.k8s.id
  cidr_block              = "10.0.1.0/28" // 16 -5 = 11 addresses total
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = true

  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "public-k8s"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.k8s.id
  availability_zone = local.availability_zone
  cidr_block        = "10.0.10.0/27" // 32 -5 = 27 addresses total
  tags = {
    Name = "private-k8s"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s.id

  tags = {
    Name = "k8s-inet-gw"
  }
}

resource "aws_eip" "natgw" {
  domain = "vpc"

  tags = {
    Name = "k8s-nat-eip"
  }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.natgw.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "k8s-natgw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.k8s.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "default-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.k8s.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "kubeadm-private_rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
