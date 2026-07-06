# Terraform Delivery Platform Summary

## Problem

Terraform changes need reviewable, repeatable, auditable delivery. A manual `terraform apply` does not provide enough evidence for production-style operations.

## Solution

This proof builds a Terraform delivery pipeline with:

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
- runtime health evidence;
- CloudTrail audit evidence;
- incident/runbook documentation.

## Environments

```text
dev -> stage -> prod
```

Each environment has separate state keys and promotion evidence.

## Evidence Collected

- plan artifact;
- `tfplan.txt` and `tfplan.json`;
- security policy result;
- cost policy result;
- risk decision;
- approval context;
- apply output;
- post-apply drift check;
- runtime health summary;
- CloudTrail audit snapshot;
- portfolio redaction checklist.
