#launch master node

resource "aws_instance" "k8s_nginx_lb" {
  ami           = var.ami["nginx_lb"]
  instance_type = var.instance_type["nginx_lb"]
  # Gán profile đã tạo ở trên vào đây
  # iam_instance_profile = aws_iam_instance_profile.k8s_node_ebs_profile_1.name

  # # QUAN TRỌNG: Để fix lỗi IMDS 404/hop limit cho CSI Driver
  # metadata_options {
  #   http_endpoint               = "enabled"
  #   http_tokens                 = "required" # Sử dụng IMDSv2
  #   http_put_response_hop_limit = 2          # Phải là 2 để Pod truy cập được metadata
  # }
  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }
  subnet_id = data.aws_subnet.dattran_subnet.id
  tags = {
    Name = "k8s_nginx_lb"
  }
  key_name        = aws_key_pair.k8s.key_name
  security_groups = [aws_security_group.k8s_nginx_lb.id]
  # depends_on      = [aws_instance.k8s_master, aws_instance.k8s_worker]
  # 
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("k8s.pem")
    host        = self.public_ip
  }
  provisioner "local-exec" {
    command = "sleep 60 && ansible-playbook -i '${self.public_ip},' installDocker.yaml"
  }

  #nginx
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' installNginx.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/nginx/tcpconf.d",
      "echo 'stream { include /etc/nginx/tcpconf.d/*.conf; }' | sudo tee -a /etc/nginx/nginx.conf"
    ]
  }
  #file browser
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' installFileBrowser.yaml"
  }
  #jenkins
  # provisioner "local-exec" {
  #   command = "ansible-playbook -i '${self.public_ip},' installjenkins.yaml"
  # }
}
resource "aws_instance" "k8s_master" {
  ami           = var.ami["master"]
  instance_type = var.instance_type["master"]
  # Gán profile đã tạo ở trên vào đây
  iam_instance_profile = aws_iam_instance_profile.k8s_node_ebs_profile_1.name

  # QUAN TRỌNG: Để fix lỗi IMDS 404/hop limit cho CSI Driver
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Sử dụng IMDSv2
    http_put_response_hop_limit = 2          # Phải là 2 để Pod truy cập được metadata
  }
  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }
  subnet_id = data.aws_subnet.dattran_subnet.id
  tags = {
    Name = "k8s_master"
  }
  key_name        = aws_key_pair.k8s.key_name
  security_groups = [aws_security_group.k8s_master.id]
  depends_on      = [aws_instance.k8s_nginx_lb]
  # 
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("k8s.pem")
    host        = self.public_ip
  }
  provisioner "file" {
    source      = "./master.sh"
    destination = "/home/ubuntu/master.sh"
  }
  provisioner "file" {
    source      = "./nginx_lb.conf"
    destination = "/home/ubuntu/nginx_lb.conf"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("k8s.pem")
      host        = aws_instance.k8s_nginx_lb.public_ip
    }
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("k8s.pem")
      host        = aws_instance.k8s_nginx_lb.public_ip
    }
    inline = [
      "sudo cp /home/ubuntu/nginx_lb.conf /etc/nginx/tcpconf.d/k8s.conf",
      "sudo sed -i 's/PLACEHOLDER_MASTER_IP_1/${aws_instance.k8s_master.private_ip}/g' /etc/nginx/tcpconf.d/k8s.conf",
      "sudo systemctl reload nginx"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sleep 60"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/master.sh",
      "sudo sh /home/ubuntu/master.sh k8s-master ${aws_instance.k8s_nginx_lb.private_ip}"
    ]
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' getJoinCommandk8s.yaml"
  }
  provisioner "local-exec" {
    # install docker
    command = "ansible-playbook -i '${self.public_ip},' installDocker.yaml"
  }
  provisioner "local-exec" {
    # install rancher
    command = "ansible-playbook -i '${self.public_ip},' installRancher.yaml"
  }
  provisioner "local-exec" {
    # fetch kubeconfig
    command = "ansible-playbook -i '${self.public_ip},' fetchKubeConfigfromMaster.yaml"
  }

}


resource "aws_instance" "k8s_master_2" {
  ami           = var.ami["master"]
  instance_type = var.instance_type["master"]
  # Gán profile đã tạo ở trên vào đây
  iam_instance_profile = aws_iam_instance_profile.k8s_node_ebs_profile_1.name

  # QUAN TRỌNG: Để fix lỗi IMDS 404/hop limit cho CSI Driver
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Sử dụng IMDSv2
    http_put_response_hop_limit = 2          # Phải là 2 để Pod truy cập được metadata
  }
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  subnet_id = data.aws_subnet.dattran_private_subnet.id
  tags = {
    Name = "k8s_master_2"
  }
  key_name        = aws_key_pair.k8s.key_name
  security_groups = [aws_security_group.k8s_master.id]
  depends_on      = [aws_instance.k8s_master]
  # 
  connection {
    type                = "ssh"
    user                = "ubuntu"
    private_key         = file("k8s.pem")
    host                = self.private_ip
    bastion_host        = aws_instance.k8s_nginx_lb.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("k8s.pem")
  }
  provisioner "file" {
    source      = "./master-2.sh"
    destination = "/home/ubuntu/master-2.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/master-2.sh",
      "sudo sh /home/ubuntu/master-2.sh k8s-master-2"
    ]
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("k8s.pem")
      host        = aws_instance.k8s_nginx_lb.public_ip
    }
    inline = [
      # Không cần cp nữa vì file đã có từ Master 1
      "sudo sed -i 's/localhost/${aws_instance.k8s_master_2.private_ip}/g' /etc/nginx/tcpconf.d/k8s.conf",
      "sudo systemctl reload nginx"
    ]
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' getJoinCommandk8s.yaml"
  }
  provisioner "local-exec" {
    # install docker
    command = "ansible-playbook -i '${self.public_ip},' installDocker.yaml"
  }
  # provisioner "local-exec" {
  #   # install rancher
  #   command = "ansible-playbook -i '${self.public_ip},' installRancher.yaml"
  # }
  # provisioner "local-exec" {
  #   # fetch kubeconfig
  #   command = "ansible-playbook -i '${self.public_ip},' fetchKubeConfigfromMaster.yaml"
  # }
  provisioner "file" {
    source      = "./join-command-master.sh"
    destination = "/home/ubuntu/join-command-master.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "set -e", # Dừng script ngay nếu có lệnh lỗi
      "echo '-------------Joining Cluster as Control Plane-------------'",

      # Kiểm tra và thực hiện Join
      "if [ -f '/home/ubuntu/join-command-master.sh' ]; then",
      "  sudo sh /home/ubuntu/join-command-master.sh",
      "else",
      "  echo 'LỖI: Không tìm thấy file join-command-master.sh!'",
      "  exit 1",
      "fi",

      "echo '-------------Cấu hình Kubeconfig cho user-------------'",

      # Tạo thư mục .kube và copy config
      "mkdir -p $HOME/.kube",
      "if [ -f '/etc/kubernetes/admin.conf' ]; then",
      "  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "  sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "  echo 'Cấu hình Kubeconfig thành công!'",
      "else",
      "  echo 'Cảnh báo: Không tìm thấy admin.conf. Có thể lệnh join chưa hoàn tất đúng cách.'",
      "fi"
    ]
  }

}

#launch worker node

resource "aws_instance" "k8s_worker" {
  count         = var.worker_count
  ami           = var.ami["worker"]
  instance_type = var.instance_type["worker"]
  # Gán profile đã tạo ở trên vào đây
  iam_instance_profile = aws_iam_instance_profile.k8s_node_ebs_profile_1.name

  # QUAN TRỌNG: Để fix lỗi IMDS 404/hop limit cho CSI Driver
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Sử dụng IMDSv2
    http_put_response_hop_limit = 2          # Phải là 2 để Pod truy cập được metadata
  }
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  subnet_id = data.aws_subnet.dattran_private_subnet.id
  tags = {
    Name = "k8s_worker-${count.index}"
  }
  key_name        = aws_key_pair.k8s.key_name
  security_groups = [aws_security_group.k8s_worker.id]
  depends_on      = [aws_instance.k8s_master]
  # 
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("k8s.pem")
    host        = self.private_ip
    # --- BASTION CONFIGURATION ---
    bastion_host        = aws_instance.k8s_nginx_lb.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("k8s.pem")
    # -----------------------------
  }
  provisioner "file" {
    source      = "./worker.sh"
    destination = "/home/ubuntu/worker.sh"
  }
  provisioner "file" {
    source      = "./join-command.sh"
    destination = "/home/ubuntu/join-command.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/worker.sh",
      "sudo sh /home/ubuntu/worker.sh k8s-worker-${count.index}",
      "chmod +x /home/ubuntu/join-command.sh",
      "sudo sh /home/ubuntu/join-command.sh"
    ]
  }
}



#NFS server
resource "aws_instance" "k8s_nfs" {
  count         = var.nfs_count
  ami           = var.ami["nfs"]
  instance_type = var.instance_type["nfs"]
  depends_on    = [aws_instance.k8s_master]
  # Gán profile đã tạo ở trên vào đây
  iam_instance_profile = aws_iam_instance_profile.k8s_node_ebs_profile_1.name
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
  subnet_id = data.aws_subnet.dattran_private_subnet.id
  tags = {
    Name = "k8s_nfs"
  }
  key_name        = aws_key_pair.k8s.key_name
  security_groups = [aws_security_group.k8s_nfs.id]
  # 

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("k8s.pem")
    host        = self.private_ip
    #bastion host
    bastion_host        = aws_instance.k8s_nginx_lb.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("k8s.pem")
  }
  # delay by remote exec
  provisioner "remote-exec" {
    inline = [
      "sleep 60"
    ]
  }
  provisioner "local-exec" {
    command = <<EOT
      ansible-playbook -i '${self.private_ip},' installNFS.yaml \
      --private-key k8s.pem \
      --user ubuntu \
      --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -i k8s.pem -o StrictHostKeyChecking=no -W %h:%p ubuntu@${aws_instance.k8s_master.public_ip}"'
    EOT
  }
}


#load balancer



// Target groups
resource "aws_lb_target_group" "k8s_tg_lb" { // Target Group A
  name     = "k8s-tg-lb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.dattran_vpc.id
  # depends_on = [aws_instance.k8s_master,
  #   aws_instance.k8s_worker,
  #   aws_instance.k8s_nginx_lb,
  #   aws_instance.k8s_nfs
  # ]
}
// Target group attachment
# attach workers node to target group use loop
resource "aws_lb_target_group_attachment" "tg_attachment_lb" {
  # count = length(aws_instance.k8s_worker)
  # Tạo một map với key là index của instance (tĩnh)
  for_each = { for x, instance in aws_instance.k8s_worker : x => instance.id }
  # for_each         = toset(aws_instance.k8s_worker[*].id)
  target_group_arn = aws_lb_target_group.k8s_tg_lb.arn
  target_id        = each.value
  port             = 80
}


resource "aws_lb" "k8s_lb" {
  name               = "k8s-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.k8s_nginx_lb.id]
  subnets            = [data.aws_subnet.dattran_subnet.id, data.aws_subnet.dattran_subnet-1.id]

  enable_deletion_protection = false

  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.id
  #   prefix  = "test-lb"
  #   enabled = true
  # }

  tags = {
    Environment = "production"
  }
}
