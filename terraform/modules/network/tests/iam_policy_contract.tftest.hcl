mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:loadbalancer/app/delivery-platform-app-alb/test"
      dns_name = "internal-delivery-platform-app-alb.example.local"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/delivery-platform-web-tg/test" }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0", latest_version = 1 }
  }
}

variables {
  aws_region           = "eu-west-1"
  project_name         = "delivery-platform"
  environment          = "test"
  vpc_cidr             = "10.20.0.0/16"
  public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
  private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
  availability_zones   = ["eu-west-1a", "eu-west-1b"]
  web_ami_id           = "ami-0123456789abcdef0"
  ssm_proxy_ami_id     = "ami-0123456789abcdef0"
}

run "runtime_iam_boundary" {
  command = apply

  assert {
    condition = (
      aws_iam_role.ssm_proxy.name == "delivery-platform-ec2-ssm-role" &&
      aws_iam_role.web_runtime.name == "delivery-platform-web-runtime-role" &&
      aws_iam_role.ssm_proxy.name != aws_iam_role.web_runtime.name
    )
    error_message = "SSM proxy and web runtime must use separate IAM roles."
  }

  assert {
    condition = (
      !strcontains(aws_iam_role_policy.web_runtime_secret_read.policy, "secret:/*") &&
      strcontains(aws_iam_role_policy.web_runtime_secret_read.policy, "secret:/devops/delivery-platform/demo/app-secret-??????") &&
      strcontains(aws_iam_role_policy.web_runtime_secret_read.policy, "parameter/devops/delivery-platform/demo/api-token")
    )
    error_message = "Runtime secret policy must use exact parameter metadata and only the AWS six-character secret ARN suffix."
  }

  assert {
    condition     = aws_iam_role_policy.web_runtime_secret_read.role == aws_iam_role.web_runtime.id
    error_message = "Application secret reads must not be attached to the SSM proxy role."
  }

  assert {
    condition = (
      endswith(aws_iam_role.ssm_proxy.permissions_boundary, "policy/delivery-platform-ssm-proxy-boundary") &&
      endswith(aws_iam_role.web_runtime.permissions_boundary, "policy/delivery-platform-web-runtime-boundary") &&
      aws_iam_role.ssm_proxy.permissions_boundary != aws_iam_role.web_runtime.permissions_boundary
    )
    error_message = "Each runtime role must use its dedicated bootstrap-owned permissions boundary."
  }
}
