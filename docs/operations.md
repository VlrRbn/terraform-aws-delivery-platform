# Operations

## Standard Change

1. Open a PR.
2. Run PR checks.
3. Merge to `main`.
4. Run `promote.yml` for `dev`.
5. Review plan/risk artifacts.
6. Approve `terraform-dev`.
7. Promote the same release ID to `stage`.
8. Promote the same release ID to `prod`.

## Drift

Run `drift-check.yml` for the target environment. Exit code `2` means Terraform found drift or an unapplied diff. Review the drift artifact before applying anything.

## Workflow Replacement Exception

Destructive actions remain denied by default. Use a two-run review process for
an intentional replacement or destroy:

1. Run `promote.yml` with `allow_destroy_file=none`. The policy blocks the
   destructive plan, but the workflow uploads its review artifact first.
2. Inspect `tfplan.json` and copy only the intended destructive Terraform
   addresses into a new JSON record under `policies/approved-destroy/`.
3. Bind the record to the exact target environment and release ID, set a real
   reviewer and reason, and use a UTC expiry no more than seven days away.
4. Merge the record through the normal PR checks, then rerun `promote.yml` with
   its repository-relative path in `allow_destroy_file`.

The second run creates a fresh plan. The policy rejects wildcard addresses,
addresses absent from that plan, unapproved additional destructive actions,
expired records, malformed fields, and environment/release mismatches.

The exception does not contain a commit SHA. Instead, the workflow generates
`destroy-exception-evidence.json` inside the immutable review artifact. It binds
the exception to `github.sha`, the binary plan SHA256, the exception SHA256,
target environment, release ID, expiry, and exact addresses. Before assuming
the apply role, the apply job verifies this evidence and the saved plan again.
Missing, altered, or mismatched evidence fails closed.

The local/admin two-step production teardown below remains a separate,
explicitly reviewed lab operation.

## Two-Step Production Teardown

Production ALB deletion protection must be disabled by a separate reviewed apply before creating the destroy plan. Run this operation with the local/admin bootstrap identity; do not grant teardown permissions to the GitHub apply role. This removes only the `prod` application environment. It does not remove `backend-bootstrap`, `ci-bootstrap`, or the audit trail.

Initialize the production root using its existing ignored local configuration:

```bash
cd /home/leprecha/terraform-aws-delivery-platform/terraform/envs/prod

AWS_PROFILE=aws-sso-admin terraform init \
  -reconfigure \
  -backend-config=backend.hcl
```

First create and inspect a normal plan that only disables ALB deletion protection:

```bash
AWS_PROFILE=aws-sso-admin terraform plan \
  -var='enable_alb_deletion_protection=false' \
  -var='prod_teardown_mode=true' \
  -out=/tmp/prod-disable-protection.tfplan

terraform show -no-color /tmp/prod-disable-protection.tfplan
```

Apply exactly that reviewed plan:

```bash
AWS_PROFILE=aws-sso-admin terraform apply \
  /tmp/prod-disable-protection.tfplan
```

Only after that apply succeeds, create and inspect a separate destroy plan. Pass the same variables so the production safety validation remains explicit during planning:

```bash
AWS_PROFILE=aws-sso-admin terraform plan \
  -destroy \
  -var='enable_alb_deletion_protection=false' \
  -var='prod_teardown_mode=true' \
  -out=/tmp/prod-destroy.tfplan

terraform show -no-color /tmp/prod-destroy.tfplan
```

Apply the exact reviewed destroy plan:

```bash
AWS_PROFILE=aws-sso-admin terraform apply \
  /tmp/prod-destroy.tfplan
```

Do not combine the protection-disable apply and destroy into one step. AWS can reject deletion of a protected ALB after Terraform has already removed dependent resources.

## Incident

Use `runbooks/` before changing state manually. Save state snapshots and AWS reality checks before recovery actions.

## Audit

Use `scripts/cloudtrail-audit-snapshot.sh` to collect AWS-side evidence after workflow runs.
