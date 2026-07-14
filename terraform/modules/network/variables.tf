variable "aws_region" {
  type        = string
  description = "AWS region, e.g. eu-west-1"
  default     = "eu-west-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must look like a valid AWS region, for example eu-west-1."
  }
}

variable "project_name" {
  type        = string
  description = "Project prefix for resource names"
  default     = "delivery-platform"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project_name))
    error_message = "project_name must be lowercase kebab-style, start with a letter, and be 3-31 characters."
  }
}

variable "environment" {
  type        = string
  description = "Environment name used for tags (dev/test/prod, etc.)"
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.environment))
    error_message = "environment must be lowercase, start with a letter, and be 2-21 characters."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "Canonical private /16 IPv4 CIDR block for the VPC"
  default     = "10.0.0.0/16"

  validation {
    condition = (
      try(cidrnetmask(var.vpc_cidr), "") == "255.255.0.0" &&
      try("${cidrhost(var.vpc_cidr, 0)}/16", "") == var.vpc_cidr &&
      try(tonumber(split(".", cidrhost(var.vpc_cidr, 0))[0]), 0) == 10
    )
    error_message = "vpc_cidr must be a canonical private 10.0.0.0/8 subnet with a /16 prefix."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDR blocks. The internal ALB design expects at least two AZs."
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "public_subnet_cidrs must contain at least two CIDRs."
  }

  validation {
    condition     = length(var.public_subnet_cidrs) <= 6
    error_message = "public_subnet_cidrs must contain at most six CIDRs because this module maps subnet keys a-f."
  }

  validation {
    condition     = length(distinct(var.public_subnet_cidrs)) == length(var.public_subnet_cidrs)
    error_message = "public_subnet_cidrs must not contain duplicate CIDRs."
  }

  validation {
    condition = alltrue([
      for cidr in var.public_subnet_cidrs :
      try(cidrnetmask(cidr), "") == "255.255.255.0" &&
      try("${cidrhost(cidr, 0)}/24", "") == cidr &&
      try(cidrsubnet(var.vpc_cidr, 8, tonumber(split(".", cidrhost(cidr, 0))[2])), "") == cidr
    ])
    error_message = "Every public subnet must be a canonical /24 contained by vpc_cidr."
  }

}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDR blocks (minimum 2 for ASG spread)"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnet CIDRs are required for the web instances."
  }

  validation {
    condition     = length(var.private_subnet_cidrs) <= 6
    error_message = "private_subnet_cidrs must contain at most six CIDRs because this module maps subnet keys a-f."
  }

  validation {
    condition     = length(distinct(var.private_subnet_cidrs)) == length(var.private_subnet_cidrs)
    error_message = "private_subnet_cidrs must not contain duplicate CIDRs."
  }

  validation {
    condition = alltrue([
      for cidr in var.private_subnet_cidrs :
      try(cidrnetmask(cidr), "") == "255.255.255.0" &&
      try("${cidrhost(cidr, 0)}/24", "") == cidr &&
      try(cidrsubnet(var.vpc_cidr, 8, tonumber(split(".", cidrhost(cidr, 0))[2])), "") == cidr
    ])
    error_message = "Every private subnet must be a canonical /24 contained by vpc_cidr."
  }

  validation {
    condition = length(distinct(concat(var.public_subnet_cidrs, var.private_subnet_cidrs))) == (
      length(var.public_subnet_cidrs) + length(var.private_subnet_cidrs)
    )
    error_message = "Public and private subnet CIDRs must not overlap."
  }

}

variable "instance_type_web" {
  type        = string
  description = "EC2 instance type for web server"
  default     = "t3.micro"
}

variable "enable_web_ssm" {
  type        = bool
  description = "Attach Session Manager permissions to web instances for controlled debugging. Runtime secret access uses a separate inline policy."
  default     = false
}

variable "web_ami_id" {
  type        = string
  description = "Baked web AMI used by the single rolling ASG fleet"

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.web_ami_id))
    error_message = "web_ami_id must look like an AWS AMI ID, for example ami-0123456789abcdef0."
  }
}

variable "tg_slow_start_seconds" {
  type        = number
  description = "Target group slow start duration in seconds (30-900)"
  default     = 60

  validation {
    condition     = var.tg_slow_start_seconds >= 30 && var.tg_slow_start_seconds <= 900
    error_message = "tg_slow_start_seconds must be between 30 and 900."
  }
}

variable "health_check_healthy_threshold" {
  type        = number
  description = "Number of consecutive successful checks before considering target healthy"
  default     = 2

  validation {
    condition     = var.health_check_healthy_threshold >= 2 && var.health_check_healthy_threshold <= 10
    error_message = "health_check_healthy_threshold must be between 2 and 10."
  }
}

variable "enable_alb_deletion_protection" {
  type        = bool
  description = "Protect the application load balancer from API deletion. Production roots must keep this enabled."
  default     = false
}

variable "web_min_size" {
  type        = number
  description = "ASG minimum size for the rolling web fleet"
  default     = 2

  validation {
    condition     = var.web_min_size >= 1
    error_message = "web_min_size must be at least 1."
  }
}

variable "web_max_size" {
  type        = number
  description = "ASG maximum size for the rolling web fleet"
  default     = 4

  validation {
    condition     = var.web_max_size >= 1
    error_message = "web_max_size must be at least 1."
  }
}

variable "web_desired_capacity" {
  type        = number
  description = "ASG desired capacity for the rolling web fleet"
  default     = 2

  validation {
    condition     = var.web_desired_capacity >= var.web_min_size && var.web_desired_capacity <= var.web_max_size
    error_message = "web_desired_capacity must be between web_min_size and web_max_size."
  }
}

variable "asg_min_healthy_percentage" {
  type        = number
  description = "Minimum healthy percentage during ASG instance refresh"
  default     = 50

  validation {
    condition     = var.asg_min_healthy_percentage >= 50 && var.asg_min_healthy_percentage <= 100
    error_message = "asg_min_healthy_percentage must be between 50 and 100."
  }
}

variable "asg_instance_warmup_seconds" {
  type        = number
  description = "Warmup time in seconds for ASG instance refresh"
  default     = 120

  validation {
    condition     = var.asg_instance_warmup_seconds >= 30
    error_message = "asg_instance_warmup_seconds must be at least 30."
  }
}

variable "asg_checkpoint_delay_seconds" {
  type        = number
  description = "Checkpoint delay in seconds for ASG instance refresh"
  default     = 180

  validation {
    condition     = var.asg_checkpoint_delay_seconds >= 30
    error_message = "asg_checkpoint_delay_seconds must be at least 30."
  }
}

variable "ssm_proxy_ami_id" {
  type        = string
  description = "AMI for the SSM proxy (must be explicit to avoid coupling with web_ami_id)"
  nullable    = false

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ssm_proxy_ami_id))
    error_message = "ssm_proxy_ami_id must look like an AWS AMI ID, for example ami-0123456789abcdef0."
  }
}

variable "common_tags" {
  type        = map(string)
  description = "Optional caller-provided tags. Required governance tags are merged after this map and cannot be overridden."
  default     = {}

  validation {
    condition     = alltrue([for k, v in var.common_tags : length(trimspace(k)) > 0 && length(trimspace(v)) > 0])
    error_message = "common_tags must not contain empty keys or empty values."
  }

  validation {
    condition = alltrue([
      for k in keys(var.common_tags) :
      !contains(["Project", "Environment", "ManagedBy", "Component"], k)
    ])
    error_message = "common_tags must not set reserved keys: Project, Environment, ManagedBy, Component."
  }
}

variable "demo_api_token_parameter_name" {
  type        = string
  description = "SSM SecureString name that the EC2 runtime role may read. Terraform should not read its plaintext value."
  default     = "/devops/delivery-platform/demo/api-token"

  validation {
    condition = (
      can(regex("^/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+$", var.demo_api_token_parameter_name)) &&
      !strcontains(var.demo_api_token_parameter_name, "//")
    )
    error_message = "demo_api_token_parameter_name must be a non-root absolute path with safe path segments."
  }
}

variable "demo_app_secret_name" {
  type        = string
  description = "Secrets Manager secret name that the EC2 runtime role may read. Terraform references metadata only."
  default     = "/devops/delivery-platform/demo/app-secret"

  validation {
    condition = (
      can(regex("^/[A-Za-z0-9_+=.@-]+(/[A-Za-z0-9_+=.@-]+)+$", var.demo_app_secret_name)) &&
      !strcontains(var.demo_app_secret_name, "//") &&
      !strcontains(var.demo_app_secret_name, "?") &&
      !strcontains(var.demo_app_secret_name, "*")
    )
    error_message = "demo_app_secret_name must be a non-root absolute path without wildcard characters."
  }
}
