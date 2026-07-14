# Security Model

## Identity

- GitHub Actions authenticates to AWS through OIDC.
- No long-lived AWS access keys are stored in GitHub.
- Plan and apply roles are separate.
- CI roles and OIDC live in the independent `terraform/ci-bootstrap` state, not in application environment state.
- Plan trust is restricted to the protected branch; PR subjects are not trusted for AWS access.
- Apply roles are scoped by GitHub Environment trust conditions.
- Bootstrap-owned permissions boundaries cap both EC2 runtime roles. Environment apply roles may manage those roles but cannot remove their boundaries or attach arbitrary managed policies.

## State

- Terraform state is stored in S3.
- State keys are separated by environment.
- The backend uses S3 lockfiles.
- Plan roles can read state and manage only the lockfile; they cannot overwrite or delete the state object.
- State files and plans are treated as sensitive operational data.

## Secrets

Terraform stores names/ARNs for runtime secret locations, not secret values.

Application secrets are read only by the web runtime role. The SSM proxy has a separate Session Manager-only identity and a boundary that excludes `ssm:GetParameter`, even though that action exists in the AWS-managed Session Manager core policy. Secret ARNs are scoped to the exact configured name plus the AWS-generated six-character suffix.

## Policy

Security and cost policies inspect Terraform JSON plans before apply. Risk classification decides whether a change can proceed and what level of approval is required.
