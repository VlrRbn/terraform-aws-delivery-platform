# Reviewed destructive-change exceptions

Files in this directory are change-control records, not permanent bypasses.

The schema in `policies/allow-destroy.example.json` requires exact Terraform
addresses from the current plan, a reason, an approver, a UTC expiry no more
than seven days away, and the exact target environment and release ID. The
security policy rejects unknown fields, wildcards, malformed or long-lived
files, mismatched workflow identity, and addresses that are not destructive in
the fresh plan.

Do not add `commit_sha` to this file. After validation, `promote.yml` generates
separate immutable evidence containing `github.sha`, the binary plan SHA256,
the exception SHA256, and the reviewed bindings. The apply job verifies that
evidence before assuming AWS credentials. See `docs/operations.md` for the
two-run review process.
