provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  environments = {
    for env, project_name in var.environment_project_names : env => {
      project_name      = project_name
      state_key         = "delivery-platform/${env}/full/terraform.tfstate"
      apply_environment = "terraform-${env}"
    }
  }

  session_manager_core_actions = [
    "ssm:DescribeAssociation", "ssm:GetDeployablePatchSnapshotForInstance", "ssm:GetDocument",
    "ssm:DescribeDocument", "ssm:GetManifest", "ssm:ListAssociations", "ssm:ListInstanceAssociations",
    "ssm:PutInventory", "ssm:PutComplianceItems", "ssm:PutConfigurePackageResult",
    "ssm:UpdateAssociationStatus", "ssm:UpdateInstanceAssociationStatus", "ssm:UpdateInstanceInformation",
    "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel",
    "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel",
    "ec2messages:AcknowledgeMessage", "ec2messages:DeleteMessage", "ec2messages:FailMessage",
    "ec2messages:GetEndpoint", "ec2messages:GetMessages", "ec2messages:SendReply",
  ]
}

# Bootstrap-owned permissions boundaries cap the effective permissions of the
# EC2 runtime roles. The environment apply roles may manage those roles, but
# they cannot turn them into an unrestricted privilege-escalation path.
resource "aws_iam_policy" "ssm_proxy_boundary" {
  for_each = local.environments
  name     = "${each.value.project_name}-ssm-proxy-boundary"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SessionManagerCoreOnly"
      Effect   = "Allow"
      Action   = local.session_manager_core_actions
      Resource = "*"
    }]
  })

  tags = {
    Project   = each.value.project_name, Environment = each.key, ManagedBy = "Terraform"
    Component = "delivery-control-plane", Role = "runtime-permissions-boundary"
  }
}

resource "aws_iam_policy" "web_runtime_boundary" {
  for_each = local.environments
  name     = "${each.value.project_name}-web-runtime-boundary"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SessionManagerCoreOnly"
        Effect   = "Allow"
        Action   = local.session_manager_core_actions
        Resource = "*"
      },
      {
        Sid      = "ReadEnvironmentRuntimeParameter"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/devops/delivery-platform/${each.key}/demo/api-token"
      },
      {
        Sid      = "ReadEnvironmentRuntimeSecret"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:/devops/delivery-platform/${each.key}/demo/app-secret-??????"
      },
    ]
  })

  tags = {
    Project   = each.value.project_name, Environment = each.key, ManagedBy = "Terraform"
    Component = "delivery-control-plane", Role = "runtime-permissions-boundary"
  }
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.github_oidc_provider_arn == "" ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

locals {
  github_oidc_provider_arn = var.github_oidc_provider_arn != "" ? var.github_oidc_provider_arn : aws_iam_openid_connect_provider.github_actions[0].arn
}

resource "aws_iam_role" "plan" {
  for_each = local.environments
  name     = "${var.role_name_prefix}-${each.key}-plan"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
        }
      }
    }]
  })

  tags = {
    Project   = each.value.project_name, Environment = each.key, ManagedBy = "Terraform"
    Component = "delivery-control-plane", Role = "ci-plan"
  }
}

resource "aws_iam_role_policy" "plan_read" {
  for_each = local.environments
  name     = "${var.role_name_prefix}-${each.key}-plan-read"
  role     = aws_iam_role.plan[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "ReadForTerraformRefresh", Effect = "Allow"
      Action = [
        "autoscaling:Describe*", "cloudwatch:Describe*", "cloudwatch:Get*", "cloudwatch:List*",
        "ec2:Describe*", "elasticloadbalancing:Describe*", "iam:Get*", "iam:List*",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "plan_backend" {
  for_each = local.environments
  name     = "${var.role_name_prefix}-${each.key}-backend"
  role     = aws_iam_role.plan[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ListStateBucket", Effect = "Allow", Action = "s3:ListBucket"
        Resource  = "arn:aws:s3:::${var.tf_state_bucket_name}"
        Condition = { StringLike = { "s3:prefix" = [each.value.state_key, "${each.value.state_key}.tflock"] } }
      },
      {
        Sid      = "ReadStateObject", Effect = "Allow", Action = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.tf_state_bucket_name}/${each.value.state_key}"
      },
      {
        Sid      = "ManageStateLockfile", Effect = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.tf_state_bucket_name}/${each.value.state_key}.tflock"
      },
    ]
  })
}

resource "aws_iam_role" "apply" {
  for_each = local.environments
  name     = "${var.role_name_prefix}-${each.key}-apply"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow", Principal = { Federated = local.github_oidc_provider_arn }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = { StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.github_repo}:environment:${each.value.apply_environment}"
      } }
    }]
  })
  tags = {
    Project   = each.value.project_name, Environment = each.key, ManagedBy = "Terraform"
    Component = "delivery-control-plane", Role = "ci-apply"
  }
}

resource "aws_iam_role_policy" "apply" {
  for_each = local.environments
  name     = "${var.role_name_prefix}-${each.key}-apply-scoped"
  role     = aws_iam_role.apply[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ListStateBucket", Effect = "Allow", Action = "s3:ListBucket"
        Resource  = "arn:aws:s3:::${var.tf_state_bucket_name}"
        Condition = { StringLike = { "s3:prefix" = [each.value.state_key, "${each.value.state_key}.tflock"] } }
      },
      {
        Sid      = "ReadWriteStateObject", Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"]
        Resource = "arn:aws:s3:::${var.tf_state_bucket_name}/${each.value.state_key}"
      },
      {
        Sid      = "ManageStateLockfile", Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.tf_state_bucket_name}/${each.value.state_key}.tflock"
      },
      {
        Sid = "ReadForTerraformRefresh", Effect = "Allow"
        Action = [
          "autoscaling:Describe*", "cloudwatch:Describe*", "cloudwatch:Get*", "cloudwatch:List*",
          "ec2:Describe*", "elasticloadbalancing:Describe*", "iam:Get*", "iam:List*",
        ]
        Resource = "*"
      },
      {
        Sid = "ManageLabEc2NetworkAndInstances", Effect = "Allow"
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway", "ec2:DeleteInternetGateway",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress", "ec2:ModifySecurityGroupRules",
          "ec2:CreateLaunchTemplate", "ec2:CreateLaunchTemplateVersion", "ec2:ModifyLaunchTemplate", "ec2:DeleteLaunchTemplate",
          "ec2:RunInstances", "ec2:TerminateInstances",
          "ec2:CreateVpcEndpoint", "ec2:ModifyVpcEndpoint", "ec2:DeleteVpcEndpoints",
          "ec2:CreateTags", "ec2:DeleteTags",
        ]
        Resource = "*"
      },
      {
        Sid = "ManageLabLoadBalancing", Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener", "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags",
        ]
        Resource = "*"
      },
      {
        Sid = "ManageLabAutoScaling", Effect = "Allow"
        Action = [
          "autoscaling:CreateAutoScalingGroup", "autoscaling:UpdateAutoScalingGroup", "autoscaling:DeleteAutoScalingGroup",
          "autoscaling:CreateOrUpdateTags", "autoscaling:DeleteTags", "autoscaling:PutScalingPolicy", "autoscaling:DeletePolicy",
          "autoscaling:StartInstanceRefresh", "autoscaling:CancelInstanceRefresh",
        ]
        Resource = "*"
      },
      {
        Sid      = "ManageLabCloudWatchAlarms", Effect = "Allow"
        Action   = ["cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:TagResource", "cloudwatch:UntagResource"]
        Resource = "*"
      },
      {
        Sid = "ManageOnlyEnvironmentRuntimeIam", Effect = "Allow"
        Action = [
          "iam:DeleteRole", "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy",
          "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile", "iam:UntagInstanceProfile",
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-ec2-ssm-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-web-runtime-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${each.value.project_name}-ec2-ssm-instance-profile",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${each.value.project_name}-web-runtime-profile",
        ]
      },
      {
        Sid      = "CreateSsmProxyRoleWithBoundary", Effect = "Allow", Action = "iam:CreateRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-ec2-ssm-role"
        Condition = { StringEquals = {
          "iam:PermissionsBoundary" = aws_iam_policy.ssm_proxy_boundary[each.key].arn
        } }
      },
      {
        Sid      = "CreateWebRuntimeRoleWithBoundary", Effect = "Allow", Action = "iam:CreateRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-web-runtime-role"
        Condition = { StringEquals = {
          "iam:PermissionsBoundary" = aws_iam_policy.web_runtime_boundary[each.key].arn
        } }
      },
      {
        Sid      = "SetSsmProxyBoundary", Effect = "Allow", Action = "iam:PutRolePermissionsBoundary"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-ec2-ssm-role"
        Condition = { StringEquals = {
          "iam:PermissionsBoundary" = aws_iam_policy.ssm_proxy_boundary[each.key].arn
        } }
      },
      {
        Sid      = "SetWebRuntimeBoundary", Effect = "Allow", Action = "iam:PutRolePermissionsBoundary"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-web-runtime-role"
        Condition = { StringEquals = {
          "iam:PermissionsBoundary" = aws_iam_policy.web_runtime_boundary[each.key].arn
        } }
      },
      {
        Sid = "DenyRuntimeBoundaryRemoval", Effect = "Deny", Action = "iam:DeleteRolePermissionsBoundary"
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-ec2-ssm-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-web-runtime-role",
        ]
      },
      {
        Sid = "AttachOnlySsmCorePolicy", Effect = "Allow", Action = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-ec2-ssm-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-web-runtime-role",
        ]
        Condition = { StringEquals = {
          "iam:PolicyARN" = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        } }
      },
      {
        Sid       = "CreateRequiredServiceLinkedRoles", Effect = "Allow", Action = "iam:CreateServiceLinkedRole", Resource = "*"
        Condition = { StringEquals = { "iam:AWSServiceName" = ["autoscaling.amazonaws.com", "elasticloadbalancing.amazonaws.com"] } }
      },
      {
        Sid = "PassOnlyEnvironmentRuntimeRolesToEc2", Effect = "Allow", Action = "iam:PassRole"
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-ec2-ssm-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.project_name}-web-runtime-role",
        ]
        Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } }
      },
    ]
  })
}
