variable "ami" {
  type = map(string)
  default = {
    "master" = "ami-09dd2e08d601bff67"
    "worker" = "ami-09dd2e08d601bff67"
  }
}