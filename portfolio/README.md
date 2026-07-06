# Terraform Delivery Pipeline Portfolio

## Overview

A production-style Terraform delivery pipeline for AWS infrastructure using GitHub Actions, OIDC, remote state, policy gates, cost controls, approvals, exact saved-plan apply, post-apply verification, and CloudTrail audit evidence.

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
-> runtime health check
-> CloudTrail audit evidence
```

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
| GitHub Environment approval | human gate |
| Exact saved plan | reproducible apply |
| Drift check | verify Terraform state after apply |
| Runtime health | verify service health |
| CloudTrail audit | verify AWS-side activity |
| Runbooks | recovery readiness |
