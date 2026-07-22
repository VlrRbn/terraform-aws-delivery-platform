# Terraform Delivery Platform Summary

## Problem

Terraform changes need reviewable, repeatable, auditable delivery. A manual `terraform apply` does not provide enough evidence for production-style operations.

## Solution

This proof builds a single-account portfolio/lab Terraform delivery pipeline
with:

- remote state and lockfile;
- GitHub Actions OIDC;
- separate plan/apply roles;
- PR checks;
- JSON plan policy;
- cost and blast-radius controls;
- risk classification;
- GitHub Environment approvals;
- exact saved-plan apply;
- post-apply drift check;
- optional runtime health evidence;
- optional CloudTrail audit evidence;
- incident/runbook documentation.

## Environments

```text
dev -> stage -> prod
```

Each environment has separate state keys and promotion evidence.

Environment-specific IAM roles, state, tags, names, and deny guardrails reduce
accidental cross-environment access inside the shared account. They are not a
hard production isolation boundary; separate application accounts are the
preferred production-like design. The solo approval gate is likewise a
deliberate pause rather than independent review.

## Evidence Collected

- plan artifact;
- `tfplan.txt` and `tfplan.json`;
- security policy result;
- cost policy result;
- risk decision;
- approval context;
- apply output;
- post-apply drift check;
- runtime health summary, when collected separately;
- CloudTrail audit snapshot, when collected separately;
- portfolio redaction checklist.
