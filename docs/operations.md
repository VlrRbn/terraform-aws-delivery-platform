# Operations

## Standard Change

1. Open a PR.
2. Run PR checks.
3. Merge to `main`.
4. Run `promote.yml` for `dev`.
5. Review plan/risk artifacts.
6. Approve `terraform-dev`.
7. Promote the same release ID to `stage`.
8. Promote the same release ID to `prod`.

## Drift

Run `drift-check.yml` for the target environment. Exit code `2` means Terraform found drift or an unapplied diff. Review the drift artifact before applying anything.

## Reviewed Replacement Or Destroy

Destructive actions remain denied by default. For an approved replacement, commit an exception under `policies/approved-destroy/` using the schema in `policies/allow-destroy.example.json`, list only exact destructive addresses from the current plan, set an expiry no more than seven days away, and pass its repository-relative path through `allow_destroy_file`. The validated exception is copied into the review artifact; GitHub Environment approval is still required. Wildcards, unrelated addresses, expired records, and long-lived approvals fail closed.

## Incident

Use `runbooks/` before changing state manually. Save state snapshots and AWS reality checks before recovery actions.

## Audit

Use `scripts/cloudtrail-audit-snapshot.sh` to collect AWS-side evidence after workflow runs.
