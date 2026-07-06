# Project Hygiene

Use this checklist before opening a PR, publishing portfolio evidence, or copying this project into a fresh repository.

## Pre-Merge Checklist

- Run `./scripts/run-local-checks.sh`.
- Run `terraform fmt -check -recursive terraform`.
- Run `packer fmt -check -recursive packer`.
- Run `checkov -d terraform --framework terraform --config-file checkov.yaml --skip-download`.
- Verify workflow YAML parses cleanly.
- Verify no raw state, plans, secrets, or evidence files are staged.
- Verify examples use placeholder values, not real account IDs, ARNs, bucket names, or AMI IDs.

## Naming Rules

- Use neutral project names such as `delivery-platform-dev`, not training-specific names.
- Use environment CIDRs that are easy to recognize: `10.20.0.0/16` for dev, `10.30.0.0/16` for stage, `10.40.0.0/16` for prod.
- Keep AMI build IDs descriptive: `demo-01`, `demo-02`, `demo-bad`, `proxy-base`, `proxy-wrk`.
- Keep GitHub Environments aligned with Terraform environments: `terraform-dev`, `terraform-stage`, `terraform-prod`.

## Comment Style

Good comments explain risk, intent, or non-obvious behavior:

- why a script fails closed;
- why an exception file must be exact-address only;
- why a workflow applies the saved binary plan;
- why a lab accepts a Checkov skip.

Avoid comments that only restate syntax:

- bad: `# Set variable`
- better: `# Do not default target env; risk level depends on environment.`

## Evidence Rules

- Treat `tfplan.json`, Terraform state, CloudTrail events, and runtime snapshots as sensitive.
- Store raw evidence under `evidence/`; it is git-ignored except for `.gitkeep`.
- Redact account IDs, ARNs, private DNS names, public IPs, bucket names, and instance IDs before publishing.
- Prefer small summaries in `portfolio/` over raw operational exports.

## CI Rules

- PR checks must not use AWS credentials.
- Static analysis belongs in its own workflow/job when it adds signal (`tflint`, `checkov`).
- Apply workflows must use exact saved plans, not re-plan after approval.
- Drift workflows must report exit code `2` as a real operational signal, not a generic failure.
- Promotion evidence must bind release ID, source environment, commit SHA, workflow URL, and policy decision.

## Manual Review Points

- Check `checkov.yaml` skips after every architecture change.
- Check IAM policies after adding new resource types.
- Check runbooks after changing backend, state key layout, or approval model.
- Check `.gitignore` after adding new tooling that creates local artifacts.
