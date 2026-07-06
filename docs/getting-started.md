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

## 3. Build AMIs With Packer

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

## 4. Configure GitHub Variables

Use `examples/github-variables.md` as the checklist.

Repository variables:

```text
AWS_REGION
TF_STATE_BUCKET
TF_WEB_AMI_ID
TF_SSM_PROXY_AMI_ID
TF_GITHUB_OWNER
TF_GITHUB_REPO
TF_GITHUB_OIDC_PROVIDER_ARN
TF_PLAN_ROLE_ARN_DEV
TF_PLAN_ROLE_ARN_STAGE
TF_PLAN_ROLE_ARN_PROD
```

GitHub Environments:

```text
terraform-dev
terraform-stage
terraform-prod
```

Environment secrets:

```text
TF_APPLY_ROLE_ARN_DEV
TF_APPLY_ROLE_ARN_STAGE
TF_APPLY_ROLE_ARN_PROD
```

## 5. Configure GitHub Environment Approval

For `terraform-dev`, `terraform-stage`, and `terraform-prod`:

- add required reviewers if you want a manual approval gate;
- disable self-review if this is a team repo;
- restrict deployment branches if needed;
- store the apply role ARN as an environment secret.

For a solo portfolio repo, self-review may be unavoidable. Document that as a portfolio limitation, not as a production recommendation.

## 6. First Dev Apply

Run `.github/workflows/promote.yml` manually:

```text
target_env: dev
release_id: demo-001
source_env: none
source_workflow_run_url: none
confirm_apply: APPLY
```

Review the generated plan artifact before approving the `terraform-dev` environment.

The apply job must use the exact reviewed saved plan.

## 7. Promote To Stage

After dev apply succeeds, copy the dev workflow run URL.

Run `promote.yml`:

```text
target_env: stage
release_id: demo-001
source_env: dev
source_workflow_run_url: https://github.com/OWNER/REPO/actions/runs/RUN_ID
confirm_apply: APPLY
```

The workflow verifies:

- source workflow finished successfully;
- source workflow SHA matches the current workflow SHA;
- source apply artifact contains a promotable manifest;
- release ID and source environment match.

## 8. Promote To Prod

After stage apply succeeds, run:

```text
target_env: prod
release_id: demo-001
source_env: stage
source_workflow_run_url: https://github.com/OWNER/REPO/actions/runs/RUN_ID
confirm_apply: APPLY
```

Prod should have the strictest approval rules.

## 9. Run Drift Checks

Use `.github/workflows/drift-check.yml` for each environment:

```text
dev
stage
prod
```

Exit code `0` means clean. Exit code `2` means drift or unapplied diff and must be reviewed.

## 10. Create The Optional Audit Trail

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

## 11. Collect CloudTrail Evidence

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

## 12. Redact Evidence Before Sharing

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

## 13. Cleanup Order

Recommended cleanup:

```text
prod -> stage -> dev -> audit-trail -> backend-bootstrap
```

Do not destroy the audit trail before collecting evidence you still need.

The CloudTrail log bucket may remain after destroy if it contains object versions. That is intentional when `force_destroy_log_bucket = false`.
