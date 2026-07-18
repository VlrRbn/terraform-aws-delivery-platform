# Getting Started: From Zero To Audited Apply

This guide shows the intended end-to-end order for running the project.

It is intentionally procedural. The shorter `README.md` explains what the project is; this file explains how the pieces fit together when you run it.

## 0. Prerequisites

Install locally:

```text
terraform
packer
awscli
jq
shellcheck
```

Optional but useful:

```text
tflint
checkov
opa
```

You also need:

- an AWS account;
- an authenticated AWS CLI profile for bootstrap/admin setup;
- a GitHub repository for this project;
- GitHub Actions enabled;
- a GitHub OIDC provider in AWS, or permission to create one through Terraform.

## 1. Run Local Checks

From repository root:

```bash
make check
```

If Terraform provider downloads are available:

```bash
make check-full
```

Static analysis:

```bash
make tflint
make checkov
```

## 2. Bootstrap Remote State

The backend bootstrap root creates the S3 bucket used for Terraform state:

```bash
cd terraform/backend-bootstrap
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Save the output bucket name. You will use it as:

```text
TF_STATE_BUCKET
```

Do not commit local `tfplan`, state, or generated backend files.

## 3. Bootstrap GitHub OIDC Roles

CI identities have their own lifecycle and state. Create them before the first workflow plan; do not try to create these roles through themselves.

```bash
cd terraform/ci-bootstrap
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
terraform output plan_role_arns
terraform output apply_role_arns
terraform output runtime_permissions_boundary_arns
```

Run this bootstrap with the same reviewed local/admin bootstrap identity used for the state bucket. Copy plan outputs to repository variables and apply outputs to the corresponding GitHub Environment secrets. The runtime boundary output is evidence that the bootstrap-owned guardrails exist; environment workflows derive the same boundary names from their fixed project names.

For an existing deployment, create the new bootstrap roles first and switch GitHub to their ARNs before planning environment roots. Environment states use `removed` blocks to forget legacy CI roles without deleting them. Review and remove those orphaned legacy roles separately only after the new workflow path is verified.

The first environment migration also removes the old inline secret policy from the proxy and creates a separate web runtime role. The policy gate will therefore require a short-lived exception for the exact address `module.network.aws_iam_role_policy.runtime_secret_read`; inspect the real plan and approve only that address. Do not add CI roles or wildcard addresses to the exception.

## 4. Build AMIs With Packer

Build the web AMI:

```bash
cd packer/web
packer init .
packer validate .
packer build .
```

Build the SSM proxy AMI:

```bash
cd ../ssm_proxy
packer init .
packer validate .
packer build .
```

Save the AMI IDs:

```text
TF_WEB_AMI_ID
TF_SSM_PROXY_AMI_ID
```

## 5. Configure GitHub Variables

Use `examples/github-variables.md` as the checklist.

Repository variables:

```text
AWS_REGION
TF_STATE_BUCKET
TF_WEB_AMI_ID
TF_SSM_PROXY_AMI_ID
TF_PLAN_ROLE_ARN_DEV
TF_PLAN_ROLE_ARN_STAGE
TF_PLAN_ROLE_ARN_PROD
```

`AWS_REGION` is a checked contract and must remain `eu-west-1`. Changing it is
not a supported migration path because it can make an existing environment look
absent and trigger unexpected recreation.

GitHub Environments:

```text
terraform-dev
terraform-stage
terraform-prod
```

Environment secrets:

```text
terraform-dev:   TF_APPLY_ROLE_ARN_DEV
terraform-stage: TF_APPLY_ROLE_ARN_STAGE
terraform-prod:  TF_APPLY_ROLE_ARN_PROD
```

## 6. Configure GitHub Environment Approval

For `terraform-dev`, `terraform-stage`, and `terraform-prod`:

- add required reviewers; without them the workflow does not wait for manual approval;
- disable self-review if this is a team repo;
- restrict deployment branches to the protected `main` branch;
- store the apply role ARN as an environment secret.

For a solo portfolio repo, self-review may be unavoidable. Document that as a portfolio limitation, not as a production recommendation.

## 7. First Dev Apply

Run `.github/workflows/promote.yml` manually:

```text
target_env: dev
release_id: demo-001
source_env: none
source_workflow_run_url: none
confirm_apply: APPLY
allow_destroy_file: none
```

Review the generated plan artifact before approving the `terraform-dev` environment.

The apply job must use the exact reviewed saved plan.

## 8. Promote To Stage

After dev apply succeeds, copy the dev workflow run URL.

Run `promote.yml`:

```text
target_env: stage
release_id: demo-001
source_env: dev
source_workflow_run_url: https://github.com/OWNER/REPO/actions/runs/RUN_ID
confirm_apply: APPLY
allow_destroy_file: none
```

The workflow verifies:

- source workflow finished successfully;
- source workflow SHA matches the current workflow SHA;
- source apply artifact contains a promotable manifest;
- release ID and source environment match.

## 9. Promote To Prod

After stage apply succeeds, run:

```text
target_env: prod
release_id: demo-001
source_env: stage
source_workflow_run_url: https://github.com/OWNER/REPO/actions/runs/RUN_ID
confirm_apply: APPLY
allow_destroy_file: none
```

Prod should have the strictest approval rules.

## 10. Run Drift Checks

Use `.github/workflows/drift-check.yml` for each environment:

```text
dev
stage
prod
```

Exit code `0` means clean. Exit code `2` means drift or unapplied diff and must be reviewed.

## 11. Create The Optional Audit Trail

The audit trail is intentionally separate from the app environments:

```bash
cd terraform/audit-trail
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

It creates:

- CloudTrail trail;
- CloudTrail log bucket;
- S3 data event selectors for Terraform state prefixes;
- lifecycle and encryption configuration for audit logs.

Keep `force_destroy_log_bucket = false` unless this is a disposable lab.

## 12. Collect CloudTrail Evidence

After a workflow run:

```bash
./scripts/cloudtrail-audit-snapshot.sh \
  --region eu-west-1 \
  --state-bucket YOUR_TFSTATE_BUCKET \
  --state-prefix delivery-platform/dev/full/ \
  --release-id demo-001 \
  --workflow-url https://github.com/OWNER/REPO/actions/runs/RUN_ID \
  --trail-name YOUR_TRAIL_NAME
```

The snapshot is read-only. It collects AWS-side evidence such as caller identity, OIDC role assumption events, service events, denied events, trail configuration, and event selectors.

## 13. Redact Evidence Before Sharing

Raw evidence can contain sensitive metadata.

```bash
./scripts/redact-evidence.sh evidence/raw-run evidence/redacted-run
```

Then review the redacted output manually.

Use:

```text
docs/redaction_checklist.md
docs/portfolio-evidence.md
portfolio/
```

## 14. Cleanup Order

Recommended cleanup:

```text
prod -> stage -> dev -> audit-trail -> backend-bootstrap
```

Prod cleanup is intentionally two-step. A direct destroy can remove dependent
resources before AWS rejects deletion of the protected ALB. First create and
review a normal saved plan with both values below, then apply only that saved
plan to disable ALB deletion protection:

```hcl
enable_alb_deletion_protection = false
prod_teardown_mode             = true
```

Only after that apply succeeds, create a fresh destroy plan and review its exact
addresses through the destructive-change exception flow. Do not use
`prod_teardown_mode` as a way to run destroy directly against an ALB whose
deletion protection is still enabled.

Do not destroy the audit trail before collecting evidence you still need.

The CloudTrail log bucket may remain after destroy if it contains object versions. That is intentional when `force_destroy_log_bucket = false`.
