variable "aws_region" {
  type    = string
  default = "eu-west-1"

  validation {
    condition     = var.aws_region == "eu-west-1"
    error_message = "The stage environment is pinned to aws_region = eu-west-1."
  }
}

variable "project_name" {
  type = string

  validation {
    condition     = var.project_name == "delivery-platform-stage"
    error_message = "The stage root accepts only project_name = delivery-platform-stage."
  }
}

variable "environment" {
  type = string

  validation {
    condition     = var.environment == "stage"
    error_message = "This root module accepts only environment = stage."
  }
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type    = list(string)
  default = ["eu-west-1a", "eu-west-1b"]

  validation {
    condition = (
      length(var.availability_zones) == 2 &&
      try(var.availability_zones[0] == "eu-west-1a", false) &&
      try(var.availability_zones[1] == "eu-west-1b", false)
    )
    error_message = "The stage environment is pinned to availability_zones = [\"eu-west-1a\", \"eu-west-1b\"]."
  }
}

variable "instance_type_web" {
  type    = string
  default = "t3.micro"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "enable_web_ssm" {
  type    = bool
  default = false
}

variable "web_ami_id" {
  type = string
}

variable "web_min_size" {
  type = number
}

variable "web_max_size" {
  type = number
}

variable "web_desired_capacity" {
  type = number
}

variable "asg_min_healthy_percentage" {
  type    = number
  default = 50

  validation {
    condition     = var.asg_min_healthy_percentage >= 50
    error_message = "stage requires asg_min_healthy_percentage >= 50."
  }
}

variable "asg_instance_warmup_seconds" {
  type    = number
  default = 120
}

variable "asg_checkpoint_delay_seconds" {
  type    = number
  default = 360
}

variable "tg_slow_start_seconds" {
  type    = number
  default = 60
}

variable "health_check_healthy_threshold" {
  type    = number
  default = 2
}

variable "enable_alb_deletion_protection" {
  type    = bool
  default = false
}

variable "ssm_proxy_ami_id" {
  type = string
}

variable "tf_state_key" {
  type = string

  validation {
    condition     = var.tf_state_key == "delivery-platform/stage/full/terraform.tfstate"
    error_message = "This root module accepts only tf_state_key = \"delivery-platform/stage/full/terraform.tfstate\"."
  }
}

variable "demo_api_token_parameter_name" {
  type = string

  validation {
    condition     = var.demo_api_token_parameter_name == "/devops/delivery-platform/stage/demo/api-token"
    error_message = "stage runtime boundary requires the standard stage demo API token path."
  }
}

variable "demo_app_secret_name" {
  type = string

  validation {
    condition     = var.demo_app_secret_name == "/devops/delivery-platform/stage/demo/app-secret"
    error_message = "stage runtime boundary requires the standard stage demo app secret path."
  }
}
