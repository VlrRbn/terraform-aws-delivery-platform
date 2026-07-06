# Terraform Layout

This directory contains multiple Terraform roots. They are intentionally separate because they have different lifecycle and risk profiles.

## Roots

| Root | Purpose | Notes |
| --- | --- | --- |
| `backend-bootstrap/` | Creates the S3 state bucket used by the delivery platform | Local/admin bootstrap step; protected with `prevent_destroy` where appropriate |
| `envs/dev/` | Development environment | Lower capacity, easier debugging |
| `envs/stage/` | Promotion/pre-production environment | Mirrors production flow with smaller blast radius |
| `envs/prod/` | Production-style environment | Stricter ASG refresh and no direct web SSM by default |
| `audit-trail/` | CloudTrail log bucket/trail and optional S3 state data events | Separate from app envs so audit lifecycle is independent |
| `modules/network/` | Shared infrastructure module | Used by dev/stage/prod roots |

## Recommended Bootstrap Order

```text
1. backend-bootstrap
2. envs/dev
3. envs/stage
4. envs/prod
5. audit-trail
```

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
