# Redaction Checklist

Before sharing screenshots, Markdown, JSON, or logs publicly, remove or mask:

## AWS Identity

- [ ] AWS account IDs
- [ ] full IAM role ARNs
- [ ] assumed-role session ARNs
- [ ] user names or SSO identities

## Network

- [ ] internal DNS names
- [ ] private IP addresses
- [ ] VPC/subnet IDs if not needed
- [ ] security group IDs if not needed

## Terraform

- [ ] raw `terraform.tfstate`
- [ ] raw `tfplan`
- [ ] raw `tfplan.json` unless reviewed
- [ ] backend bucket names if sensitive
- [ ] state object version IDs if sensitive

## CloudTrail

- [ ] raw CloudTrail events with account/session metadata
- [ ] source IP addresses
- [ ] request parameters containing internal IDs
- [ ] error messages with sensitive resource names

## Secrets And Notifications

- [ ] secret values
- [ ] SSM parameter values
- [ ] Secrets Manager values
- [ ] budget email addresses
- [ ] webhook URLs

## Final Check

- [ ] public README explains architecture without leaking account details
- [ ] proof-pack references redacted evidence only
- [ ] raw evidence stays in ignored local folder
