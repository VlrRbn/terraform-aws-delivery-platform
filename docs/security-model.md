# Security Model

## Identity

- GitHub Actions authenticates to AWS through OIDC.
- No long-lived AWS access keys are stored in GitHub.
- Plan and apply roles are separate.
- Apply roles are scoped by GitHub Environment trust conditions.

## State

- Terraform state is stored in S3.
- State keys are separated by environment.
- The backend uses S3 lockfiles.
- State files and plans are treated as sensitive operational data.

## Secrets

Terraform stores names/ARNs for runtime secret locations, not secret values.

Application secrets should be read by runtime IAM roles from AWS services such as Secrets Manager or SSM Parameter Store.

## Policy

Security and cost policies inspect Terraform JSON plans before apply. Risk classification decides whether a change can proceed and what level of approval is required.
