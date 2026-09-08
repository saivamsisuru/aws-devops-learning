resource "aws_vpc" "myvpc"{
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "myvpc1"
        Environment = "Production"
    }
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true

    tags = {
        Name = "public-subnet-1a"
    }
}

resource "aws_subnet" "private"{
    vpc_id=aws_vpc.myvpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "ap-south-1b"

    tags = {
        Name = "private-subnet-1b"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.myvpc.id

    tags = {
        Name = "myvpc1-igw"
    }
}

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.myvpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "public-route-table"
    }
}

resource "aws_route_table_association" "public_assoc" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public_rt.id

}