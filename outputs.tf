output "master" {
  value = aws_instance.k8s_master.public_ip
}

output "worker" {
  value = aws_instance.k8s_worker[*].public_ip
}

