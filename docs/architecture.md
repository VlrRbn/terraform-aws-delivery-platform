# Architecture

The platform deploys an internal AWS web stack and the delivery controls around it.

![Terraform AWS Delivery Platform Architecture](architecture.svg)

## Infrastructure

- VPC with public and private subnets
- Internal Application Load Balancer
- Auto Scaling Group for web instances
- SSM proxy instance for private operational access
- VPC interface endpoints for SSM and runtime secret access
- CloudWatch alarms for release/runtime signals
- IAM roles for EC2 runtime, GitHub Actions plan, and GitHub Actions apply

## Environments

Each environment has an isolated Terraform root and state key:

```text
dev   -> delivery-platform/dev/full/terraform.tfstate
stage -> delivery-platform/stage/full/terraform.tfstate
prod  -> delivery-platform/prod/full/terraform.tfstate
```

The same `network` module is used in every environment. Differences are expressed through environment inputs, not through copied module code.

## Account Topology

This portfolio/lab deployment intentionally keeps `dev`, `stage`, and `prod` in one AWS account. Separate Terraform states, environment-specific plan/apply roles, fixed project names, resource tags, and deny-only cross-environment IAM guardrails reduce accidental access between environments. These controls are useful defense in depth, but they are not a hard isolation boundary: an account-level administrator remains able to affect every environment, and some AWS authorization paths cannot be constrained reliably by resource tags alone.

For a production-like deployment, prefer three application accounts: one each for `dev`, `stage`, and `prod`. Give GitHub OIDC a separate plan/apply role in each target account and keep state access scoped to that environment. A separate tooling account for CI/bootstrap and a log-archive account for audit evidence can be added when the operational scope justifies them. The single-account layout remains appropriate for this portfolio/lab because it is cheaper and simpler to operate; moving to multiple accounts is a deliberate architecture change, not a missing setup step.

## Delivery Control Plane

GitHub Actions uses OIDC to assume roles owned by the independent `terraform/ci-bootstrap` state. The branch-bound plan role can read infrastructure and the state object but can mutate only the S3 lockfile. The apply role is gated by GitHub Environment approval and applies only the reviewed saved plan.
