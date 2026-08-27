variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr_block" {
  type    = string
  default = "10.0.10.0/24"
}

variable "avail_zone" {
  type    = string
  default = "us-east-2a"
}

variable "env_prefix" {
  type    = string
  default = "dev"
}

variable "my_ip" {
  type = string
  default = "172.13.111.146/32"
}

variable "jenkins_ip" {
  type = string
  default = "192.34.56.63/32"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "region" {
  type    = string
  default = "us-east-2"
}

variable cidr_block {
  default = "0.0.0.0/0"
}



