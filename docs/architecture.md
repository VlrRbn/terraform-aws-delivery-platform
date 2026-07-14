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

## Delivery Control Plane

GitHub Actions uses OIDC to assume roles owned by the independent `terraform/ci-bootstrap` state. The branch-bound plan role can read infrastructure and the state object but can mutate only the S3 lockfile. The apply role is gated by GitHub Environment approval and applies only the reviewed saved plan.
