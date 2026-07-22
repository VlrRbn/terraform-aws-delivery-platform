mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
}

variables {
  aws_region                    = "eu-west-1"
  project_name                  = "delivery-platform-dev"
  environment                   = "dev"
  vpc_cidr                      = "10.20.0.0/16"
  public_subnet_cidrs           = ["10.20.1.0/24", "10.20.2.0/24"]
  private_subnet_cidrs          = ["10.20.11.0/24", "10.20.12.0/24"]
  availability_zones            = ["eu-west-1a", "eu-west-1b"]
  web_ami_id                    = "ami-0123456789abcdef0"
  ssm_proxy_ami_id              = "ami-0123456789abcdef0"
  web_min_size                  = 1
  web_desired_capacity          = 1
  web_max_size                  = 2
  tf_state_key                  = "delivery-platform/dev/full/terraform.tfstate"
  demo_api_token_parameter_name = "/devops/delivery-platform/dev/demo/api-token"
  demo_app_secret_name          = "/devops/delivery-platform/dev/demo/app-secret"
}

run "dev_rejects_wrong_availability_zones" {
  command = plan

  variables {
    availability_zones = ["eu-west-1b", "eu-west-1a"]
  }

  expect_failures = [var.availability_zones]
}

run "dev_rejects_wrong_region" {
  command = plan

  variables {
    aws_region = "us-east-1"
  }

  expect_failures = [var.aws_region]
}

run "dev_rejects_wrong_project_name" {
  command = plan

  variables {
    project_name = "delivery-platform-prod"
  }

  expect_failures = [var.project_name]
}
