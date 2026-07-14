variable "aws_region" {
  type        = string
  description = "AWS region used by the delivery platform."
  default     = "eu-west-1"
}

variable "github_owner" {
  type        = string
  description = "GitHub organization or username allowed to assume the CI roles."
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.github_owner))
    error_message = "github_owner must contain only letters, numbers, and hyphens."
  }
}

variable "github_repo" {
  type        = string
  description = "GitHub repository allowed to assume the CI roles."
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.github_repo))
    error_message = "github_repo must contain only letters, numbers, dots, underscores, and hyphens."
  }
}

variable "github_branch" {
  type        = string
  description = "Protected branch allowed to assume plan roles."
  default     = "main"
  validation {
    condition     = length(trimspace(var.github_branch)) > 0
    error_message = "github_branch must not be empty."
  }
}

variable "github_oidc_provider_arn" {
  type        = string
  description = "Existing GitHub Actions OIDC provider ARN. Leave empty to create it in this bootstrap state."
  default     = ""
  validation {
    condition = (
      var.github_oidc_provider_arn == "" ||
      can(regex("^arn:aws:iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.github_oidc_provider_arn))
    )
    error_message = "github_oidc_provider_arn must be empty or the GitHub Actions OIDC provider ARN."
  }
}

variable "tf_state_bucket_name" {
  type        = string
  description = "Remote state S3 bucket used by environment roots."
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.tf_state_bucket_name))
    error_message = "tf_state_bucket_name must look like a valid S3 bucket name."
  }
}

variable "role_name_prefix" {
  type        = string
  description = "Prefix for CI roles. It must stay distinct from environment project prefixes."
  default     = "delivery-platform-ci"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,40}$", var.role_name_prefix))
    error_message = "role_name_prefix must be lowercase kebab-style and 3-41 characters."
  }
}

variable "environment_project_names" {
  type        = map(string)
  description = "Application project prefix per environment; used only to scope mutable resources and PassRole."
  default = {
    dev   = "delivery-platform-dev"
    stage = "delivery-platform-stage"
    prod  = "delivery-platform-prod"
  }
  validation {
    condition = (
      length(var.environment_project_names) == 3 &&
      alltrue([for env in ["dev", "stage", "prod"] : contains(keys(var.environment_project_names), env)]) &&
      alltrue([for name in values(var.environment_project_names) : can(regex("^[a-z][a-z0-9-]{2,30}$", name))])
    )
    error_message = "environment_project_names must define valid dev, stage, and prod project prefixes."
  }
}
