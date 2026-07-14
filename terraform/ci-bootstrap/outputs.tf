output "plan_role_arns" {
  description = "Plan role ARNs keyed by environment."
  value       = { for env, role in aws_iam_role.plan : env => role.arn }
}

output "apply_role_arns" {
  description = "Apply role ARNs keyed by environment. Store each value as a GitHub Environment secret."
  value       = { for env, role in aws_iam_role.apply : env => role.arn }
}

output "runtime_permissions_boundary_arns" {
  description = "Bootstrap-owned runtime permissions boundary ARNs keyed by environment and runtime role."
  value = {
    for env in keys(local.environments) : env => {
      ssm_proxy   = aws_iam_policy.ssm_proxy_boundary[env].arn
      web_runtime = aws_iam_policy.web_runtime_boundary[env].arn
    }
  }
}

output "github_oidc_provider_arn" {
  description = "OIDC provider used by all delivery roles."
  value       = local.github_oidc_provider_arn
}
