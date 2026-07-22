mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
}

variables {
  aws_region                    = "eu-west-1"
  project_name                  = "delivery-platform-stage"
  environment                   = "stage"
  vpc_cidr                      = "10.30.0.0/16"
  public_subnet_cidrs           = ["10.30.1.0/24", "10.30.2.0/24"]
  private_subnet_cidrs          = ["10.30.11.0/24", "10.30.12.0/24"]
  availability_zones            = ["eu-west-1a", "eu-west-1b"]
  web_ami_id                    = "ami-0123456789abcdef0"
  ssm_proxy_ami_id              = "ami-0123456789abcdef0"
  web_min_size                  = 2
  web_desired_capacity          = 2
  web_max_size                  = 3
  tf_state_key                  = "delivery-platform/stage/full/terraform.tfstate"
  demo_api_token_parameter_name = "/devops/delivery-platform/stage/demo/api-token"
  demo_app_secret_name          = "/devops/delivery-platform/stage/demo/app-secret"
}

run "stage_rejects_wrong_availability_zones" {
  command = plan

  variables {
    availability_zones = ["eu-west-1b", "eu-west-1a"]
  }

  expect_failures = [var.availability_zones]
}

run "stage_rejects_wrong_region" {
  command = plan

  variables {
    aws_region = "us-east-1"
  }

  expect_failures = [var.aws_region]
}

run "stage_rejects_wrong_project_name" {
  command = plan

  variables {
    project_name = "delivery-platform-prod"
  }

  expect_failures = [var.project_name]
}
