# Reviewed destructive-change exceptions

Files in this directory are change-control records, not permanent bypasses.

Use the same strict schema as `policies/allow-destroy.example.json`: exact Terraform addresses, a reason, an approver, and a non-expired UTC date. Reference the committed file through the `allow_destroy_file` workflow input. The security policy rejects wildcards, malformed files, expired records, and addresses not present in the exception.
