# Terraform Layout

This directory contains multiple Terraform roots. They are intentionally separate because they have different lifecycle and risk profiles.

## Roots

| Root | Purpose | Notes |
| --- | --- | --- |
| `backend-bootstrap/` | Creates the S3 state bucket used by the delivery platform | Local/admin bootstrap step; protected with `prevent_destroy` where appropriate |
| `ci-bootstrap/` | Creates GitHub OIDC plan/apply roles and runtime permissions boundaries in a dedicated remote state | Local/admin bootstrap step; outputs populate GitHub variables and environment secrets |
| `envs/dev/` | Development environment | Lower capacity, easier debugging |
| `envs/stage/` | Promotion/pre-production environment | Mirrors production flow with smaller blast radius |
| `envs/prod/` | Production-style environment | Stricter ASG refresh, ALB deletion protection, and no direct web SSM by default |
| `audit-trail/` | CloudTrail log bucket/trail and optional S3 state data events | Separate lifecycle; trail and bucket are protected by `prevent_destroy` |
| `modules/network/` | Shared infrastructure module | Used by dev/stage/prod roots |

The three application roots are disposable. Keep `backend-bootstrap/` and
`ci-bootstrap/` when environments will be recreated by later workflow runs;
keep `audit-trail/` for as long as its evidence is required. See
`docs/operations.md` for the production teardown sequence.

## Recommended Bootstrap Order

```text
1. backend-bootstrap
2. ci-bootstrap
3. envs/dev
4. envs/stage
5. envs/prod
6. audit-trail
```

Never bootstrap `ci-bootstrap/` through a role that it is creating. Run its reviewed saved plan with the same local/admin bootstrap identity used for the backend, then configure GitHub with its outputs.

`audit-trail/` can be created earlier if you want to capture events from the first environment applies, but it needs the state bucket name/prefixes to configure S3 data event selectors.

## Runtime Files

Do not commit:

```text
backend.hcl
terraform.tfvars
terraform.auto.tfvars
terraform.tfstate*
tfplan*
.terraform/
```

Use `*.example` files locally and `scripts/write-terraform-env-files.sh` in CI.

## Validation

From repository root:

```bash
RUN_TERRAFORM=true ./scripts/run-local-checks.sh
```

For individual roots:

```bash
terraform -chdir=terraform/audit-trail init -backend=false
terraform -chdir=terraform/audit-trail validate
```
