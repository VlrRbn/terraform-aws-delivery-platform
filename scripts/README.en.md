# Terraform Delivery Platform Scripts

This folder contains helper scripts for local checks, review evidence, runtime health evidence, and incident recovery evidence.

## Scripts

The scripts do not change the infrastructure or its state.

| Script | Purpose |
| --- | --- |
| `run-local-checks.sh` | Runs safe local checks. |
| `write-terraform-env-files.sh` | Generates temporary `backend.hcl` and `terraform.auto.tfvars` for CI. |
| `promotion-evidence-template.sh` | Generates valid promotion evidence JSON. |
| `reviewer-note-template.sh` | Generates a Markdown reviewer note from `risk-decision.json`. |
| `runtime-health-check.sh` | Collects read-only ALB/ASG/CloudWatch runtime evidence. |
| `state-snapshot.sh` | Pulls current state and plan into local evidence before recovery. |
| `post-incident-check.sh` | Captures post-incident plan status. |
| `cloudtrail-audit-snapshot.sh` | Collects CloudTrail/AWS-side audit evidence for a workflow run or incident. |
| `list-state-versions.sh` | Lists S3 versions for a Terraform state key. |
| `incident-decision-template.sh` | Generates an incident decision note template. |
| `collect-proof.sh` | Copies known evidence into one timestamped folder. |
| `summarize-proof.sh` | Generates `proof-review-summary.md` from evidence. |
| `redact-evidence.sh` | Creates a redacted copy of evidence before sharing. |

## Local checks

Run from repo root:

```bash
scripts/run-local-checks.sh
```

Optional checks:

```bash
RUN_OPA=true scripts/run-local-checks.sh
RUN_TERRAFORM=true scripts/run-local-checks.sh
```

## CI helper

```bash
AWS_REGION=eu-west-1 \
TF_STATE_BUCKET=example-tfstate \
TF_WEB_AMI_ID=ami-0123456789abcdef0 \
TF_SSM_PROXY_AMI_ID=ami-0123456789abcdef0 \
TF_GITHUB_OWNER=example-org \
TF_GITHUB_REPO=terraform-aws-delivery-platform \
TF_GITHUB_OIDC_PROVIDER_ARN=arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com \
scripts/write-terraform-env-files.sh dev
```

This script exists for GitHub Actions: `backend.hcl` and `terraform.auto.tfvars` are not stored in Git, so a clean runner must create them before `terraform init`.

## Review helpers

```bash
scripts/promotion-evidence-template.sh \
  delivery-platform-demo \
  dev \
  "$(git rev-parse HEAD)" \
  "https://github.com/OWNER/REPO/actions/runs/123456789" \
  > /tmp/promotion-evidence-stage.json
```

```bash
scripts/reviewer-note-template.sh \
  /tmp/delivery-platform-risk/risk-decision.json \
  > /tmp/delivery-platform-reviewer-note.md
```

## Runtime and incident evidence

These commands read AWS/Terraform data and write local evidence bundles:

```bash
AWS_REGION=eu-west-1 scripts/runtime-health-check.sh dev
scripts/state-snapshot.sh dev
scripts/post-incident-check.sh dev
```

## CloudTrail audit evidence

Use this after a workflow run, incident drill, or recovery action when you need AWS-side evidence:

```bash
scripts/cloudtrail-audit-snapshot.sh \
  --region eu-west-1 \
  --state-bucket example-tfstate \
  --state-prefix delivery-platform/dev/full/ \
  --release-id release-001 \
  --workflow-url https://github.com/OWNER/REPO/actions/runs/123456789
```

If an audit trail was created with `terraform/audit-trail/`, pass the trail name too:

```bash
scripts/cloudtrail-audit-snapshot.sh \
  --region eu-west-1 \
  --trail-name delivery-platform-terraform-audit \
  --state-bucket example-tfstate \
  --state-prefix delivery-platform/dev/full/
```

## Proof pack helpers

```bash
scripts/collect-proof.sh dev
scripts/summarize-proof.sh evidence/<folder>
scripts/redact-evidence.sh evidence/raw-run evidence/redacted-run
```

`collect-proof.sh` copies known files only. It does not redact evidence automatically. Review the output before sharing or committing anything.

It also does not search outputs in `/tmp`. If you ran `security-policy.sh`, `cost-policy.sh`, or `risk-classifier.sh` with `OUT_DIR=/tmp/...`, copy those directories into the evidence folder before running `summarize-proof.sh`.

## Safety Notes

- Scripts do not run `terraform apply` or `terraform destroy`.
- Runtime/state scripts can call AWS APIs and Terraform read-only commands.
- Generated evidence can contain ARNs, account IDs, DNS names, IPs, and operational metadata.
- Do not commit raw evidence unless it is intentionally redacted.
