variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string

  validation {
    condition     = var.environment == "prod"
    error_message = "This root module accepts only environment = prod."
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
  default = 100

  validation {
    condition     = var.asg_min_healthy_percentage == 100
    error_message = "prod requires asg_min_healthy_percentage = 100."
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
  default = true

  validation {
    condition     = var.enable_alb_deletion_protection
    error_message = "prod requires enable_alb_deletion_protection = true."
  }
}

variable "ssm_proxy_ami_id" {
  type = string
}

variable "tf_state_key" {
  type = string

  validation {
    condition     = var.tf_state_key == "delivery-platform/prod/full/terraform.tfstate"
    error_message = "This root module accepts only tf_state_key = \"delivery-platform/prod/full/terraform.tfstate\"."
  }
}

variable "demo_api_token_parameter_name" {
  type = string

  validation {
    condition     = var.demo_api_token_parameter_name == "/devops/delivery-platform/prod/demo/api-token"
    error_message = "prod runtime boundary requires the standard prod demo API token path."
  }
}

variable "demo_app_secret_name" {
  type = string

  validation {
    condition     = var.demo_app_secret_name == "/devops/delivery-platform/prod/demo/app-secret"
    error_message = "prod runtime boundary requires the standard prod demo app secret path."
  }
}
