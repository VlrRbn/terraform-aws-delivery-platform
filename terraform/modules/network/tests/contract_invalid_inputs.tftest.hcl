mock_provider "aws" {
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

run "insufficient_availability_zones_fail" {
  command = plan

  variables {
    availability_zones = ["eu-west-1a"]
  }

  expect_failures = [var.availability_zones]
}

run "availability_zone_outside_region_fails" {
  command = plan

  variables {
    availability_zones = ["eu-west-1a", "us-east-1b"]
  }

  expect_failures = [var.availability_zones]
}

run "duplicate_availability_zones_fail" {
  command = plan

  variables {
    availability_zones = ["eu-west-1a", "eu-west-1a"]
  }

  expect_failures = [var.availability_zones]
}

run "too_many_availability_zones_fail" {
  command = plan

  variables {
    availability_zones = [
      "eu-west-1a",
      "eu-west-1b",
      "eu-west-1c",
      "eu-west-1d",
      "eu-west-1e",
      "eu-west-1f",
      "eu-west-1g",
    ]
  }

  expect_failures = [var.availability_zones]
}

run "bad_project_name_fails" {
  command = plan

  variables {
    project_name = "Bad_Name"
  }

  expect_failures = [
    var.project_name
  ]
}

run "bad_web_ami_id_fails" {
  command = plan

  variables {
    web_ami_id = "ubuntu-latest"
  }

  expect_failures = [
    var.web_ami_id
  ]
}

run "single_private_subnet_fails" {
  command = plan

  variables {
    private_subnet_cidrs = ["10.20.11.0/24"]
  }

  expect_failures = [
    var.private_subnet_cidrs
  ]
}

run "too_many_private_subnets_fails" {
  command = plan

  variables {
    private_subnet_cidrs = [
      "10.20.11.0/24",
      "10.20.12.0/24",
      "10.20.13.0/24",
      "10.20.14.0/24",
      "10.20.15.0/24",
      "10.20.16.0/24",
      "10.20.17.0/24",
    ]
  }

  expect_failures = [
    var.private_subnet_cidrs
  ]
}

run "duplicate_private_subnets_fail" {
  command = plan

  variables {
    private_subnet_cidrs = ["10.20.11.0/24", "10.20.11.0/24"]
  }

  expect_failures = [
    var.private_subnet_cidrs
  ]
}

run "bad_private_subnet_cidr_fails" {
  command = plan

  variables {
    private_subnet_cidrs = ["10.20.11.0/24", "not-a-cidr"]
  }

  expect_failures = [
    var.private_subnet_cidrs
  ]
}

run "bad_ssm_proxy_ami_id_fails" {
  command = plan

  variables {
    ssm_proxy_ami_id = "ubuntu-latest"
  }

  expect_failures = [
    var.ssm_proxy_ami_id
  ]
}

run "empty_tag_value_fails" {
  command = plan

  variables {
    common_tags = {
      Owner = ""
    }
  }

  expect_failures = [
    var.common_tags
  ]
}

run "reserved_tag_override_fails" {
  command = plan

  variables {
    common_tags = {
      Project = "manual"
    }
  }

  expect_failures = [
    var.common_tags
  ]
}

run "bad_health_check_threshold_fails" {
  command = plan

  variables {
    health_check_healthy_threshold = 1
  }

  expect_failures = [
    var.health_check_healthy_threshold
  ]
}

run "subnet_outside_vpc_fails" {
  command = plan

  variables {
    private_subnet_cidrs = ["10.99.11.0/24", "10.20.12.0/24"]
  }

  expect_failures = [
    var.private_subnet_cidrs
  ]
}

run "public_private_overlap_fails" {
  command = plan

  variables {
    public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
    private_subnet_cidrs = ["10.20.1.0/24", "10.20.12.0/24"]
  }

  expect_failures = [var.private_subnet_cidrs]
}

run "unsafe_refresh_percentage_fails" {
  command = plan

  variables {
    asg_min_healthy_percentage = 49
  }

  expect_failures = [var.asg_min_healthy_percentage]
}

run "root_secret_path_fails" {
  command = plan

  variables {
    demo_app_secret_name = "/"
  }

  expect_failures = [var.demo_app_secret_name]
}
