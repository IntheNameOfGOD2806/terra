# Fetch the existing VPC by its Name tag
data "aws_vpc" "dattran_vpc" {
  filter {
    name   = "tag:Name"
    values = ["dattran-vpc"]
  }
}

# Fetch the existing Subnet within that VPC
data "aws_subnet" "dattran_subnet" {
  filter {
    name   = "tag:Name"
    values = ["public-subnet"]
  }
  vpc_id = data.aws_vpc.dattran_vpc.id
}