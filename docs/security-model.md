# Security Model

## Identity

- GitHub Actions authenticates to AWS through OIDC.
- No long-lived AWS access keys are stored in GitHub.
- Plan and apply roles are separate.
- CI roles and OIDC live in the independent `terraform/ci-bootstrap` state, not in application environment state.
- Plan trust is restricted to the protected branch; PR subjects are not trusted for AWS access.
- Apply roles are scoped by GitHub Environment trust conditions.
- GitHub Environments retain a manual approval pause. The solo portfolio/lab permits owner self-review; this is not an independent approval boundary. Team and production-like deployments should disable self-review and require another reviewer.
- Bootstrap-owned permissions boundaries cap both EC2 runtime roles. Environment apply roles may manage those roles but cannot remove their boundaries or attach arbitrary managed policies.
- Apply roles also carry a deny-only cross-environment policy. It rejects other environment request/resource tags and known ALB, target group, listener, ASG, and alarm name prefixes. This single-account plus deny-guardrail model is appropriate for the portfolio/lab deployment; three application accounts (`dev`, `stage`, and `prod`) are the preferred production-like boundary. See `docs/architecture.md` for the topology and its limitations.

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
