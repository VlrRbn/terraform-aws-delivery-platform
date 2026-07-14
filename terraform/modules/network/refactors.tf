moved {
  from = aws_cloudwatch_metric_alarm.release_target_5xx
  to   = aws_cloudwatch_metric_alarm.release_5xx_gate
}

moved {
  from = aws_iam_role.ec2_ssm_role
  to   = aws_iam_role.ssm_proxy
}

moved {
  from = aws_iam_role_policy_attachment.ec2_ssm_role_attach
  to   = aws_iam_role_policy_attachment.ssm_proxy_core
}

moved {
  from = aws_iam_instance_profile.ec2_ssm_instance_profile
  to   = aws_iam_instance_profile.ssm_proxy
}

# CI roles now belong to terraform/ci-bootstrap. Forget the legacy copies without
# deleting credentials that may still be needed during the cutover.
removed {
  from = aws_iam_openid_connect_provider.github_actions
  lifecycle { destroy = false }
}

removed {
  from = aws_iam_role.github_actions_plan_role
  lifecycle { destroy = false }
}

removed {
  from = aws_iam_role_policy.github_actions_plan_read
  lifecycle { destroy = false }
}

removed {
  from = aws_iam_role_policy.github_actions_backend_access
  lifecycle { destroy = false }
}

removed {
  from = aws_iam_role.github_actions_apply_role
  lifecycle { destroy = false }
}

removed {
  from = aws_iam_role_policy.github_actions_apply_scoped
  lifecycle { destroy = false }
}
