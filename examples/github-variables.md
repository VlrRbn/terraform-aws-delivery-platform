# GitHub Variables and Environments

## Repository Variables

```text
AWS_REGION=eu-west-1
TF_STATE_BUCKET=YOUR_TFSTATE_BUCKET
TF_WEB_AMI_ID=ami-xxxxxxxxxxxxxxxxx
TF_SSM_PROXY_AMI_ID=ami-xxxxxxxxxxxxxxxxx
TF_GITHUB_OWNER=YOUR_GITHUB_OWNER
TF_GITHUB_REPO=terraform-aws-delivery-platform
TF_GITHUB_OIDC_PROVIDER_ARN=arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
TF_PLAN_ROLE_ARN_DEV=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-dev-github-actions-plan-role
TF_PLAN_ROLE_ARN_STAGE=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-stage-github-actions-plan-role
TF_PLAN_ROLE_ARN_PROD=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-prod-github-actions-plan-role
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
TF_APPLY_ROLE_ARN_DEV=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-dev-github-actions-apply-role
TF_APPLY_ROLE_ARN_STAGE=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-stage-github-actions-apply-role
TF_APPLY_ROLE_ARN_PROD=arn:aws:iam::ACCOUNT_ID:role/delivery-platform-prod-github-actions-apply-role
```
