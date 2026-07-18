# GitHub Variables and Environments

## Repository Variables

```text
AWS_REGION=eu-west-1
TF_STATE_BUCKET=YOUR_TFSTATE_BUCKET
TF_WEB_AMI_ID=ami-xxxxxxxxxxxxxxxxx
TF_SSM_PROXY_AMI_ID=ami-xxxxxxxxxxxxxxxxx
TF_PLAN_ROLE_ARN_DEV=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-ci-dev-plan
TF_PLAN_ROLE_ARN_STAGE=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-ci-stage-plan
TF_PLAN_ROLE_ARN_PROD=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-ci-prod-plan
```

## GitHub Environments

Create:

```text
terraform-dev
terraform-stage
terraform-prod
```

Environment secrets:

```text
terraform-dev:   TF_APPLY_ROLE_ARN_DEV=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-ci-dev-apply
terraform-stage: TF_APPLY_ROLE_ARN_STAGE=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-ci-stage-apply
terraform-prod:  TF_APPLY_ROLE_ARN_PROD=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-ci-prod-apply
```

Configure required reviewers and restrict deployments to the protected `main`
branch. Merely creating a GitHub Environment does not add a manual approval gate.

The role ARNs come from `terraform/ci-bootstrap` outputs. GitHub owner/repository and OIDC provider configuration are inputs to that bootstrap root, not repository variables consumed by promotion workflows.
