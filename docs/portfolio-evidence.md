# Portfolio Evidence

Useful public evidence should be redacted and small.

Good examples:

- workflow screenshots with account IDs masked;
- redacted plan/risk summaries;
- policy deny/warn examples;
- CloudTrail role assumption event with ARNs partially masked;
- runbook excerpts;
- architecture diagram.

Do not publish:

- raw `tfplan.json`;
- raw Terraform state;
- unredacted CloudTrail events;
- private IP ranges if you do not want them public;
- account IDs, role ARNs, bucket names, or internal DNS names without masking.
