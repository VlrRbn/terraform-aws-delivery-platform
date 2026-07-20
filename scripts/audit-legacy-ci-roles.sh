#!/usr/bin/env bash
set -Eeuo pipefail

# Read-only inventory for CI roles forgotten by removed { destroy = false }.
# The script never deletes, detaches, updates, or assumes a role.

AWS_REGION="${AWS_REGION:-eu-west-1}"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

if ! command -v aws >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "aws and jq are required" >&2
  exit 1
fi

account_id="$(aws sts get-caller-identity --query Account --output text)"
echo "Legacy CI role inventory for account ${account_id} (${AWS_REGION})"

found=0
for target_env in dev stage prod; do
  project_name="delivery-platform-${target_env}"

  for role_kind in plan apply; do
    role_name="${project_name}-github-actions-${role_kind}-role"
    role_json="$TMP_ROOT/${role_name}.json"
    error_file="$TMP_ROOT/${role_name}.error"

    if aws iam get-role --role-name "$role_name" --output json >"$role_json" 2>"$error_file"; then
      found=$((found + 1))
      jq '{
        role_name: .Role.RoleName,
        arn: .Role.Arn,
        created: .Role.CreateDate,
        last_used: (.Role.RoleLastUsed.LastUsedDate // null),
        last_used_region: (.Role.RoleLastUsed.Region // null),
        trust_subjects: [
          .Role.AssumeRolePolicyDocument.Statement[]?.Condition[]?["token.actions.githubusercontent.com:sub"]
        ] | flatten | map(select(. != null))
      }' "$role_json"

      aws iam list-role-policies --role-name "$role_name" --output json
      aws iam list-attached-role-policies --role-name "$role_name" --output json
    elif [[ "$(<"$error_file")" == *NoSuchEntity* ]]; then
      echo "NOT_FOUND ${role_name}"
    else
      echo "Failed to inspect ${role_name}:" >&2
      sed -n '1,5p' "$error_file" >&2
      exit 1
    fi
  done
done

if [[ "$found" -eq 0 ]]; then
  echo "No legacy environment-owned GitHub Actions roles were found."
else
  echo "Found ${found} legacy role(s). Review trust and last-used evidence before any separate retirement operation."
fi
