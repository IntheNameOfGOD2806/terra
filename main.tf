#launch master node

resource "aws_instance" "k8s_master" {
  ami           = "ami-09dd2e08d601bff67"
  instance_type = "t2.medium"
  tags = {
    Name = "k8s_master"
  }
}