#launch master node

resource "aws_instance" "k8s_master" {
  ami           = var.ami["master"]
  instance_type = var.instance_type["master"]
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

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/master.sh",
      "sudo sh /home/ubuntu/master.sh k8s-master"
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




#launch worker node

resource "aws_instance" "k8s_worker" {
  count         = var.worker_count
  ami           = var.ami["worker"]
  instance_type = var.instance_type["worker"]
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  subnet_id = data.aws_subnet.dattran_subnet.id
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
    host        = self.public_ip
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


resource "aws_instance" "k8s_nginx_lb" {
  ami           = var.ami["nginx_lb"]
  instance_type = var.instance_type["nginx_lb"]
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
  depends_on      = [aws_instance.k8s_master, aws_instance.k8s_worker]
  # 
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("k8s.pem")
    host        = self.public_ip
  }
  provisioner "local-exec" {
    # install rancher
    command = "ansible-playbook -i '${self.public_ip},' installNginx.yaml"
  }
  provisioner "local-exec" {
    # install file browser
    command = "ansible-playbook -i '${self.public_ip},' installFileBrowser.yaml"
  }
  # provisioner "file" {
  #   source      = "./join-command.sh"
  #   destination = "/home/ubuntu/join-command.sh"
  # }
  # provisioner "remote-exec" {
  #   inline = [
  #     "chmod +x /home/ubuntu/worker.sh",
  #     "sudo sh /home/ubuntu/worker.sh k8s-worker-${count.index}",
  #     "chmod +x /home/ubuntu/join-command.sh",
  #     "sudo sh /home/ubuntu/join-command.sh"
  #   ]
  # }
}
