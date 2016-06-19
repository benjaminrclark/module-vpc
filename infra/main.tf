# Provider
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags { Name = "otto" }
}

# AWS Internet gateway. Routes traffic from 
# Public subnets to the internet
resource "aws_internet_gateway" "public" {
  vpc_id = "${aws_vpc.main.id}"
}

# Public subnets 
# 10.0.0.0/24 - 10.0.n.0/24 
resource "aws_subnet" "public" {
    count                   = "${var.aws_availability_zone_count}"
    availability_zone       = "${element(split(",",lookup(var.aws_availability_zones, var.aws_region)),count.index)}"
    vpc_id                  = "${aws_vpc.main.id}"
    cidr_block              = "10.0.${count.index + 1}.0/24"
    map_public_ip_on_launch = true
    tags { Name = "public" }
}

# Public subnet route table
# routes traffic to the internet via the internet gateway
resource "aws_route_table" "public" {
  count  = "${var.aws_availability_zone_count}"
  vpc_id = "${aws_vpc.main.id}"
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.public.id}"
  }
  tags { Name = "public" }
}

resource "aws_route_table_association" "public" {
  count  = "${var.aws_availability_zone_count}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.public.*.id, count.index)}"
}

# Elastic IP in each private subnet for the NAT
# 10.0.*.4
resource "aws_eip" "nat" {
  count = "${var.aws_availability_zone_count}"
  associate_with_private_ip = "${cidrhost(element(aws_subnet.public.*.cidr_block, count.index),4)}"
  vpc = true
}

# NAT allows private instances to connect to the internet via the internet gateway
resource "aws_nat_gateway" "default" {
  count = "${var.aws_availability_zone_count}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  depends_on = ["aws_internet_gateway.public"]
}

# Private subnet without publically addressable ips, non-local traffic routed via the NAT
resource "aws_subnet" "private" {
    count                   = "${var.aws_availability_zone_count}"
    availability_zone       = "${element(split(",",lookup(var.aws_availability_zones, var.aws_region)),count.index)}"
    vpc_id                  = "${aws_vpc.main.id}"
    cidr_block              = "10.0.${var.aws_availability_zone_count + count.index + 1}.0/24"
    tags { Name = "private" }
}

resource "aws_route_table" "private" {
  count  = "${var.aws_availability_zone_count}"
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block  = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.default.*.id, count.index)}"
  }
  tags { Name = "private" }
}

resource "aws_route_table_association" "private" {
  count  = "${var.aws_availability_zone_count}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

# Allow SSH ingress and egress, plus http and https egress for updates
resource "aws_security_group" "bastion" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name = "bastion"
  }
}

resource "aws_security_group_rule" "bastion_ssh_ingress" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.bastion.id}"
}

resource "aws_security_group_rule" "bastion_ssh_egress" {
  type = "egress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.bastion.id}"
}

resource "aws_security_group_rule" "bastion_http_egress" {
  type = "egress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.bastion.id}"
}

resource "aws_security_group_rule" "bastion_https_egress" {
  type = "egress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.bastion.id}"
}

# One bastion instance in each availability zone
# 10.0.*.5
resource "aws_instance" "bastion" {
  count                       = "${var.aws_availability_zone_count}"
  availability_zone           = "${element(split(",",lookup(var.aws_availability_zones, var.aws_region)),count.index)}"
  ami                         = "${var.bastion_ami}"
  instance_type               = "${var.bastion_instance_type}"
  key_name                    = "${aws_key_pair.main.key_name}"
  monitoring                  = true
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]
  subnet_id                   = "${element(aws_subnet.public.*.id, count.index)}"
  private_ip                  = "${cidrhost(element(aws_subnet.public.*.cidr_block, count.index),5)}"
  associate_public_ip_address = true
  tags {
    Name = "bastion"
  }
}

resource "aws_key_pair" "main" {
  key_name   = "otto-${element(split("-", aws_vpc.main.id), 1)}"
  public_key = "${var.ssh_public_key}"
}
