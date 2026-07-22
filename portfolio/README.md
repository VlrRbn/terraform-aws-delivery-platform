# Terraform Delivery Pipeline Portfolio

## Overview

A portfolio/lab implementation of a production-style Terraform delivery
pipeline for AWS infrastructure using GitHub Actions, OIDC, remote state,
policy gates, cost controls, approvals, exact saved-plan apply, post-apply
verification, and optional AWS-side evidence collection.

It uses one AWS account with environment-specific roles, state, naming, tags,
and deny guardrails. These controls reduce accidental cross-environment access
but do not replace account isolation. Separate `dev`, `stage`, and `prod`
application accounts are the preferred production-like design. The solo GitHub
approval gate also permits self-review and is not independent approval.

## Architecture

- IaC: Terraform
- CI/CD: GitHub Actions
- Identity: AWS OIDC with separate plan/apply roles
- State: S3 remote backend with lockfile
- Environments: dev, stage, prod
- Audit: GitHub artifacts + CloudTrail events

## Delivery Flow

```text
PR checks
-> protected branch
-> plan
-> policy gates
-> cost gates
-> risk classification
-> approval
-> exact saved-plan apply
-> post-apply drift check
```

Runtime health and CloudTrail snapshots are collected separately when that
evidence is needed; they are not automatic `promote.yml` steps.

## Controls Implemented

| Control | Purpose |
| --- | --- |
| Remote state + lockfile | state safety |
| OIDC | no static AWS keys |
| Plan/apply role split | least privilege |
| Module tests | contract protection |
| JSON plan policy | block risky changes |
| Cost policy | limit cost/blast radius |
| Risk classifier | match review to risk |
| GitHub Environment approval | deliberate pause; independent only with another reviewer |
| Exact saved plan | reproducible apply |
| Drift check | verify Terraform state after apply |
| Runtime health helper | optionally verify service health after a run |
| CloudTrail audit helper | optionally verify AWS-side activity |
| Runbooks | recovery readiness |
