mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
}

variables {
  aws_region               = "eu-west-1"
  github_owner             = "example-org"
  github_repo              = "terraform-aws-delivery-platform"
  github_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  tf_state_bucket_name     = "example-tfstate-123456789012"
}

run "least_privilege_ci_roles" {
  command = apply

  assert {
    condition = (
      strcontains(aws_iam_role.plan["dev"].assume_role_policy, "ref:refs/heads/main") &&
      !strcontains(aws_iam_role.plan["dev"].assume_role_policy, "pull_request")
    )
    error_message = "Plan trust must be restricted to the protected branch and must not trust PR subjects."
  }

  assert {
    condition = (
      !strcontains(aws_iam_role_policy.plan_read["dev"].policy, "ssm:GetParameter") &&
      !strcontains(aws_iam_role_policy.plan_read["dev"].policy, "secretsmanager:GetSecretValue")
    )
    error_message = "Plan roles must not read runtime secret values."
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(aws_iam_role_policy.plan_backend["dev"].policy).Statement :
      statement.Sid != "ReadStateObject" || (
        statement.Action == "s3:GetObject" &&
        !strcontains(jsonencode(statement), "s3:PutObject") &&
        !strcontains(jsonencode(statement), "s3:DeleteObject")
      )
    ])
    error_message = "Plan role must only read the state object; writes and deletes belong only to the lockfile statement."
  }

  assert {
    condition = alltrue([
      for action in ["ec2:CreateVpcEndpoint", "ec2:ModifyVpcEndpoint", "ec2:DeleteVpcEndpoints"] :
      strcontains(aws_iam_role_policy.apply["dev"].policy, action)
    ])
    error_message = "Apply role must include the exact VPC endpoint CRUD actions required by the module."
  }

  assert {
    condition = (
      aws_iam_role.apply["dev"].name == "delivery-platform-ci-dev-apply" &&
      !startswith(aws_iam_role.apply["dev"].name, "delivery-platform-dev-") &&
      !strcontains(aws_iam_role_policy.apply["dev"].policy, "role/delivery-platform-dev-*") &&
      !strcontains(aws_iam_role_policy.apply["dev"].policy, "instance-profile/delivery-platform-dev-*")
    )
    error_message = "Apply role must stay outside its managed IAM resources, which must use exact runtime role/profile ARNs."
  }

  assert {
    condition = (
      strcontains(aws_iam_policy.ssm_proxy_boundary["dev"].policy, "SessionManagerCoreOnly") &&
      !strcontains(aws_iam_policy.ssm_proxy_boundary["dev"].policy, "ssm:GetParameter") &&
      !strcontains(aws_iam_policy.ssm_proxy_boundary["dev"].policy, "secretsmanager:GetSecretValue")
    )
    error_message = "The SSM proxy boundary must allow session core actions without runtime secret reads."
  }

  assert {
    condition = (
      strcontains(aws_iam_policy.web_runtime_boundary["dev"].policy, "parameter/devops/delivery-platform/dev/demo/api-token") &&
      strcontains(aws_iam_policy.web_runtime_boundary["dev"].policy, "secret:/devops/delivery-platform/dev/demo/app-secret-??????") &&
      !strcontains(aws_iam_policy.web_runtime_boundary["dev"].policy, "Action\":\"*")
    )
    error_message = "The web runtime boundary must cap secret reads to the configured environment paths."
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(aws_iam_role_policy.apply["dev"].policy).Statement :
      !strcontains(jsonencode(statement.Action), "iam:AttachRolePolicy") ||
      try(statement.Condition.StringEquals["iam:PolicyARN"], "") == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ])
    error_message = "Every managed-policy attachment permission must be restricted to AmazonSSMManagedInstanceCore."
  }

  assert {
    condition = (
      strcontains(aws_iam_role_policy.apply["dev"].policy, "DenyRuntimeBoundaryRemoval") &&
      alltrue([
        for statement in jsondecode(aws_iam_role_policy.apply["dev"].policy).Statement :
        !strcontains(jsonencode(statement.Action), "iam:CreateRole") ||
        contains([
          aws_iam_policy.ssm_proxy_boundary["dev"].arn,
          aws_iam_policy.web_runtime_boundary["dev"].arn,
        ], try(statement.Condition.StringEquals["iam:PermissionsBoundary"], ""))
      ])
    )
    error_message = "Apply role must require the bootstrap boundaries and must not permit arbitrary managed-policy attachment."
  }
}
