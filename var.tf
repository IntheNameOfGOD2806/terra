variable "ami" {
  type = map(string)
  default = {
    "master"   = "ami-0e7ff22101b84bcff"
    "worker"   = "ami-0e7ff22101b84bcff"
    "nginx_lb" = "ami-0e7ff22101b84bcff"
    "nfs"      = "ami-0e7ff22101b84bcff"
  }
}

variable "instance_type" {
  type = map(string)
  default = {
    "master"   = "t2.medium"
    "worker"   = "t2.medium"
    "nginx_lb" = "t2.medium"
    "nfs"      = "t2.medium"
  }
}

variable "worker_count" {
  type    = number
  default = 3
}
variable "nfs_count" {
  type    = number
  default = 2
}

variable "region" {
  default = "ap-southeast-1"
}
