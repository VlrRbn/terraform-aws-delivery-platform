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

All three runs must also use the same commit SHA. If `main` changes during the
chain, restart from `dev` for the new SHA.

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

The local/admin teardown procedures below remain separate, explicitly reviewed
lab operations.

## Prepare Local Environment Configuration

Workflow runners generate ignored Terraform configuration on demand. Generate
the same files locally before planning a teardown; do not rely on files left by
an earlier shell session:

```bash
export REPO_ROOT="$(git rev-parse --show-toplevel)"
export AWS_REGION="eu-west-1"
export TF_STATE_BUCKET="YOUR_TFSTATE_BUCKET"
export TF_WEB_AMI_ID="ami-xxxxxxxxxxxxxxxxx"
export TF_SSM_PROXY_AMI_ID="ami-xxxxxxxxxxxxxxxxx"
```

The AMI IDs remain required Terraform inputs even when the intended plan is a
destroy. Use the values currently configured as GitHub repository variables.

## Development And Stage Teardown

Select one disposable non-production environment and generate its exact
configuration:

```bash
export TARGET_ENV="dev" # or stage

"$REPO_ROOT/scripts/write-terraform-env-files.sh" "$TARGET_ENV"
"$REPO_ROOT/scripts/validate-terraform-env-config.sh" "$TARGET_ENV"

terraform -chdir="$REPO_ROOT/terraform/envs/$TARGET_ENV" init \
  -reconfigure \
  -backend-config=backend.hcl
```

Create and inspect a saved destroy plan:

```bash
AWS_PROFILE=aws-sso-admin terraform \
  -chdir="$REPO_ROOT/terraform/envs/$TARGET_ENV" plan \
  -destroy \
  -out="/tmp/${TARGET_ENV}-destroy.tfplan"

terraform show -no-color "/tmp/${TARGET_ENV}-destroy.tfplan"
```

After confirming that the plan affects only the selected application root,
apply that exact saved plan:

```bash
AWS_PROFILE=aws-sso-admin terraform \
  -chdir="$REPO_ROOT/terraform/envs/$TARGET_ENV" apply \
  "/tmp/${TARGET_ENV}-destroy.tfplan"
```

## Two-Step Production Teardown

Production ALB deletion protection must be disabled by a separate reviewed apply before creating the destroy plan. Run this operation with the local/admin bootstrap identity; do not grant teardown permissions to the GitHub apply role. This removes only the `prod` application environment. It does not remove `backend-bootstrap`, `ci-bootstrap`, or the audit trail.

Generate and validate the production configuration, then initialize its root:

```bash
"$REPO_ROOT/scripts/write-terraform-env-files.sh" prod
"$REPO_ROOT/scripts/validate-terraform-env-config.sh" prod

AWS_PROFILE=aws-sso-admin terraform \
  -chdir="$REPO_ROOT/terraform/envs/prod" init \
  -reconfigure \
  -backend-config=backend.hcl
```

First create and inspect a normal plan that only disables ALB deletion protection:

```bash
AWS_PROFILE=aws-sso-admin terraform \
  -chdir="$REPO_ROOT/terraform/envs/prod" plan \
  -var='enable_alb_deletion_protection=false' \
  -var='prod_teardown_mode=true' \
  -out=/tmp/prod-disable-protection.tfplan

terraform show -no-color /tmp/prod-disable-protection.tfplan
```

Apply exactly that reviewed plan:

```bash
AWS_PROFILE=aws-sso-admin terraform \
  -chdir="$REPO_ROOT/terraform/envs/prod" apply \
  /tmp/prod-disable-protection.tfplan
```

Only after that apply succeeds, create and inspect a separate destroy plan. Pass the same variables so the production safety validation remains explicit during planning:

```bash
AWS_PROFILE=aws-sso-admin terraform \
  -chdir="$REPO_ROOT/terraform/envs/prod" plan \
  -destroy \
  -var='enable_alb_deletion_protection=false' \
  -var='prod_teardown_mode=true' \
  -out=/tmp/prod-destroy.tfplan

terraform show -no-color /tmp/prod-destroy.tfplan
```

Apply the exact reviewed destroy plan:

```bash
AWS_PROFILE=aws-sso-admin terraform \
  -chdir="$REPO_ROOT/terraform/envs/prod" apply \
  /tmp/prod-destroy.tfplan
```

Do not combine the protection-disable apply and destroy into one step. AWS can reject deletion of a protected ALB after Terraform has already removed dependent resources.

## Incident

Use `runbooks/` before changing state manually. Save state snapshots and AWS reality checks before recovery actions.

## Audit

Use `scripts/cloudtrail-audit-snapshot.sh` to collect AWS-side evidence after workflow runs.
