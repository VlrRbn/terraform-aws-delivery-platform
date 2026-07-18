# Reviewed destructive-change exceptions

Files in this directory are change-control records, not permanent bypasses.

Use the same strict schema as `policies/allow-destroy.example.json`: exact Terraform addresses from the current plan, a reason, an approver, and a UTC expiry no more than seven days away. Reference the committed file through the `allow_destroy_file` workflow input. The security policy rejects wildcards, malformed or long-lived files, and addresses that are not destructive in the current plan.
