variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_version" {
  type    = string
  default = "blue"
}

variable "build_id" {
  # Deployment identity shown on the page (examples: demo-01, demo-02, demo-bad).
  type    = string
  default = "demo-01"
}
