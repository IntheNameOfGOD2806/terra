variable "ami" {
  type = map(string)
  default = {
    "master" = "ami-09dd2e08d601bff67"
    "worker" = "ami-09dd2e08d601bff67"
  }
}

variable "instance_type" {
  type = map(string)
  default = {
    "master" = "t2.medium"
    "worker" = "t2.medium"
  }
}

variable "worker_count" {
  type = number
  default = 2
}