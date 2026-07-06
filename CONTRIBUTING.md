# Contributing

This repository is optimized for clear review, safe Terraform delivery, and portfolio-quality evidence.

## Local Checks Before PR

Run the fast checks first:

```bash
make check
```

Run deeper Terraform checks when provider downloads are available:

```bash
make check-full
```

Run static analysis separately when needed:

```bash
make tflint
make checkov
```

## Change Rules

- Do not commit Terraform state, plans, raw evidence, secrets, or generated `backend.hcl` / `terraform.auto.tfvars`.
- Keep examples using placeholders, not real account IDs, ARNs, AMI IDs, bucket names, or DNS names.
- Keep `dev`, `stage`, and `prod` roots structurally aligned unless the difference is intentional and documented.
- If a policy skip is added to `checkov.yaml`, add a reason.
- If IAM permissions expand, explain why the new API action is required.
- If a workflow changes apply behavior, explain how exact-plan apply and approval are preserved.

## PR Checklist

- [ ] `make check` passes.
- [ ] `make checkov` passes or every finding is intentionally documented.
- [ ] `make tflint` passes.
- [ ] Workflow YAML still parses.
- [ ] No raw evidence or runtime Terraform files are staged.
- [ ] README/docs are updated when workflow, state layout, or IAM model changes.
- [ ] New scripts include `set -Eeuo pipefail`, help text, and clear exit behavior.

## Evidence Handling

Raw evidence belongs under `evidence/` and is ignored by git. To prepare shareable evidence:

```bash
scripts/redact-evidence.sh evidence/raw-run evidence/redacted-run
```

Review redacted output manually before publishing.

## Commit Style

Use concise, scoped messages:

```text
feat(ci): add terraform quality gates
fix(iam): narrow apply role permissions
docs(runbooks): clarify stuck lock recovery
chore(repo): add redaction helper
```
