resource "aws_subnet" "private_ap_southeast_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[0]
  availability_zone = "ap-southeast-1a"

  tags = {
    "Name"                            = "${var.env}-private-ap-southeast-1a"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/demo"      = "owned"
  }
}

resource "aws_subnet" "private_ap_southeast_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[1]
  availability_zone = "ap-southeast-1b"

  tags = {
    "Name"                            = "${var.env}-private-ap-southeast-1b"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/demo"      = "owned"
  }
}

resource "aws_subnet" "public_ap_southeast_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[0]
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true

  tags = {
    "Name"                       = "${var.env}-private-ap-southeast-1a"
    "kubernetes.io/role/elb"     = "1"
    "kubernetes.io/cluster/demo" = "owned"
  }
}

resource "aws_subnet" "public_ap_southeast_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[1]
  availability_zone       = "ap-southeast-1b"
  map_public_ip_on_launch = true

  tags = {
    "Name"                       = "${var.env}-private-ap-southeast-1"
    "kubernetes.io/role/elb"     = "1"
    "kubernetes.io/cluster/demo" = "owned"
  }
}
