# Terraform Delivery Platform Scripts

This folder contains helper scripts for local checks, review evidence, runtime health evidence, and incident recovery evidence.

## Scripts

The scripts do not change the infrastructure or its state.

| Script | Purpose |
| --- | --- |
| `run-local-checks.sh` | Runs safe local checks. |
| `write-terraform-env-files.sh` | Generates temporary `backend.hcl` and `terraform.auto.tfvars` for CI. |
| `validate-terraform-env-config.sh` | Fails closed when backend key, region, project, environment, or the fixed `eu-west-1a`/`eu-west-1b` Availability Zones do not match the selected root. |
| `test-terraform-env-config.sh` | Runs positive and negative tests for generated environment configuration. |
| `audit-legacy-ci-roles.sh` | Inventories old environment-owned CI roles and last-used evidence without changing AWS. |
| `audit-github-environments.sh` | Verifies a manual reviewer, deployment branches, and environment-specific apply-role secret names through the read-only GitHub API; optional strict mode also requires independent review. |
| `test-workflow-guardrails.sh` | Tests action SHA pins, the exact Checkov `3.3.8` pin, the stable `TFLint and Checkov` PR check, destructive-exception evidence, and positive/negative GitHub Environment audit fixtures. |
| `destroy-exception-evidence.sh` | Creates and verifies immutable commit, plan, exception, and workflow-binding evidence for approved destructive changes. |
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
scripts/write-terraform-env-files.sh dev
```

This script exists for GitHub Actions: `backend.hcl` and `terraform.auto.tfvars` are not stored in Git, so a clean runner must create them before `terraform init`.

Validate generated or manually prepared files before initialization:

```bash
scripts/validate-terraform-env-config.sh dev
```

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

Inventory CI roles left active by the state cutover:

```bash
AWS_PROFILE=YOUR_READ_ONLY_PROFILE scripts/audit-legacy-ci-roles.sh
```

Verify GitHub Environment protection rules:

```bash
gh auth login
scripts/audit-github-environments.sh OWNER/REPO
```

The default matches the solo portfolio/lab model: a required reviewer must be
configured, but self-review may remain enabled. Team and production-like setups
can require independent approval explicitly:

```bash
REQUIRE_INDEPENDENT_REVIEW=true scripts/audit-github-environments.sh OWNER/REPO
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
