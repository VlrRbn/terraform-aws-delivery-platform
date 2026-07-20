# Reviewed destructive-change exceptions

Files in this directory are change-control records, not permanent bypasses.

Use the same strict schema as `policies/allow-destroy.example.json`: exact Terraform addresses from the current plan, a reason, an approver, a UTC expiry no more than seven days away, and the exact target environment, release ID, and full commit SHA. Reference the committed file through the `allow_destroy_file` workflow input. The security policy rejects wildcards, malformed or long-lived files, mismatched workflow identity, and addresses that are not destructive in the current plan.
