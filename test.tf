output "test" {
  value = <<-EOT
    ssh ubuntu@123 "kubectl get svc -A | grep ingress-nginx | grep NodePort | awk '{split(\$6, a, \"[:/]\"); print a[2]}'"
  EOT
}
