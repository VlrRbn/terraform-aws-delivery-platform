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

## Incident

Use `runbooks/` before changing state manually. Save state snapshots and AWS reality checks before recovery actions.

## Audit

Use `scripts/cloudtrail-audit-snapshot.sh` to collect AWS-side evidence after workflow runs.
