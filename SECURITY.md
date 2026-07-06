# Security Policy

## Supported Scope

This project is a portfolio/reference implementation for Terraform delivery controls on AWS. Security reports should focus on this repository content:

- GitHub Actions workflows
- Terraform IAM, state, networking, and delivery controls
- policy scripts and test fixtures
- evidence/redaction helpers
- runbooks and operational procedures

## Do Not Share Sensitive Data

Do not open issues or PRs containing:

- Terraform state files
- raw `tfplan` or unreviewed `tfplan.json`
- AWS account IDs, full ARNs, bucket names, private DNS names, or IPs
- CloudTrail events with unredacted identity/session metadata
- secrets, tokens, webhook URLs, private keys, or SSM/Secrets Manager values

Use `scripts/redact-evidence.sh` before sharing evidence externally.

## Reporting A Security Issue

If this is your fork or private copy, report issues through your normal private channel first.

For a public portfolio repo, use one of these safe patterns:

- open a GitHub issue with redacted reproduction details;
- open a PR with a minimal fix and no raw evidence;
- include sanitized snippets only, not full logs or state.

## Expected Security Model

- GitHub Actions uses OIDC, not long-lived AWS keys.
- Plan and apply roles are separated.
- Apply requires GitHub Environment approval.
- Terraform applies the saved reviewed binary plan.
- Policy scripts fail closed on malformed inputs.
- Raw operational evidence is ignored by git.

## Non-Goals

This project intentionally keeps some lab tradeoffs documented instead of implementing every production hardening option by default. Examples include HTTP-only internal ALB traffic, limited logging defaults, and low-cost S3 encryption choices. These tradeoffs are documented in `checkov.yaml` and `docs/project-hygiene.md`.
