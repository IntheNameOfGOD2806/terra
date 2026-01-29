resource "aws_security_group" "k8s_master" {
  name        = "k8s_master_sg"
  description = "k8s master sg"
  vpc_id      = data.aws_vpc.dattran_vpc.id

  tags = {
    Name = "k8s_master_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "SSH" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_ingress_rule" "api_server" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6443
  ip_protocol = "tcp"
  to_port     = 6443
}

resource "aws_vpc_security_group_ingress_rule" "ETCD" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 2379
  ip_protocol = "tcp"
  to_port     = 2380
}

resource "aws_vpc_security_group_ingress_rule" "weavenet_tcp" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6783
  ip_protocol = "tcp"
  to_port     = 6783
}
# resource "aws_vpc_security_group_ingress_rule" "rancher_444" {
#   security_group_id = aws_security_group.k8s_master.id
#   cidr_ipv4         = "0.0.0.0/0"
#   #cidr_ipv6         = "::/0"
#   from_port   = 444
#   ip_protocol = "tcp"
#   to_port     = 444
# }
resource "aws_vpc_security_group_ingress_rule" "rancher_81" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 81
  ip_protocol = "tcp"
  to_port     = 81
}

resource "aws_vpc_security_group_ingress_rule" "weavenet_udp" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6784
  ip_protocol = "udp"
  to_port     = 6784
}

resource "aws_vpc_security_group_ingress_rule" "kubelet_and_control_plane" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 10248
  ip_protocol = "tcp"
  to_port     = 10260
}

resource "aws_vpc_security_group_ingress_rule" "NodePort_Service" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 30000
  ip_protocol = "tcp"
  to_port     = 32767
}

resource "aws_vpc_security_group_ingress_rule" "HTTP" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "HTTPS" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_ingress_rule" "HTTP_8080" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 8080
  ip_protocol = "tcp"
  to_port     = 8080
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  ip_protocol = "-1" # semantically equivalent to all ports
}


#worker
resource "aws_security_group" "k8s_worker" {
  name        = "k8s_worker_sg"
  description = "k8s worker sg"
  vpc_id      = data.aws_vpc.dattran_vpc.id

  tags = {
    Name = "k8s_worker_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "SSH_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_ingress_rule" "api_server_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6443
  ip_protocol = "tcp"
  to_port     = 6443
}

resource "aws_vpc_security_group_ingress_rule" "ETCD_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 2379
  ip_protocol = "tcp"
  to_port     = 2380
}

resource "aws_vpc_security_group_ingress_rule" "weavenet_tcp_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6783
  ip_protocol = "tcp"
  to_port     = 6783
}

resource "aws_vpc_security_group_ingress_rule" "weavenet_udp_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6784
  ip_protocol = "udp"
  to_port     = 6784
}

resource "aws_vpc_security_group_ingress_rule" "kubelet_and_control_plane_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 10248
  ip_protocol = "tcp"
  to_port     = 10260
}

resource "aws_vpc_security_group_ingress_rule" "NodePort_Service_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 30000
  ip_protocol = "tcp"
  to_port     = 32767
}

resource "aws_vpc_security_group_ingress_rule" "HTTP_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "HTTPS_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_ingress_rule" "HTTP_8080_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 8080
  ip_protocol = "tcp"
  to_port     = 8080
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

