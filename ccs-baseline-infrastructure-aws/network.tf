resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.deployment_name}-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.main.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.deployment_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.deployment_name}-igw"
  }
}

data "aws_route_table" "public_subnets" {
  vpc_id = aws_vpc.main.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

resource "aws_ec2_tag" "route_table_public_subnets" {
  resource_id = data.aws_route_table.public_subnets.id
  key         = "Name"
  value       = "${var.deployment_name}-rt-public-subnets"
}

resource "aws_route" "public_subnets_igw" {
  route_table_id         = data.aws_route_table.public_subnets.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_eip" "natgw" {
  tags = {
    Name = "${var.deployment_name}-natgw-eip"
  }
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.natgw.id
  subnet_id     = aws_subnet.public_subnet[0].id
  tags = {
    Name = "${var.deployment_name}-natgw"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_subnet" "private_subnet" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.main.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + length(aws_subnet.public_subnet))
  tags = {
    Name = "${var.deployment_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "private_subnets" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.deployment_name}-rt-private-subnets"
  }
}

resource "aws_route_table_association" "private_subnets" {
  count          = length(aws_subnet.private_subnet)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_subnets.id
}

resource "aws_route" "private_subnets_natgw" {
  route_table_id         = aws_route_table.private_subnets.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw.id
}
