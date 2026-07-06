mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:loadbalancer/app/delivery-platform-app-alb/test"
      dns_name = "internal-delivery-platform-app-alb.example.local"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/delivery-platform-web-tg/test"
    }
  }
}

variables {
  aws_region           = "eu-west-1"
  project_name         = "delivery-platform"
  environment          = "test"
  vpc_cidr             = "10.20.0.0/16"
  public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
  private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
  web_ami_id           = "ami-0123456789abcdef0"
  ssm_proxy_ami_id     = "ami-0123456789abcdef0"
  github_owner         = "example-org"
  github_repo          = "terraform-aws-delivery-platform"
  tf_state_bucket_name = "vlrrbn-tfstate-123456789012-eu-west-1"
  tf_state_key         = "delivery-platform/dev/full/terraform.tfstate"

  common_tags = {
    Owner = "devops-track"
  }
}

run "valid_contract_inputs_plan" {
  command = plan

  assert {
    condition     = output.web_asg_name == "delivery-platform-web-asg"
    error_message = "web_asg_name must keep the stable '<project>-web-asg' output contract."
  }

  assert {
    condition     = output.demo_api_token_parameter_name == "/devops/delivery-platform/demo/api-token"
    error_message = "The runtime SSM parameter output must expose only the stable metadata name."
  }

  assert {
    condition     = output.demo_app_secret_name == "/devops/delivery-platform/demo/app-secret"
    error_message = "The runtime Secrets Manager output must expose only the stable metadata name."
  }
}
