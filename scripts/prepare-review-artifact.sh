#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
: "${TARGET_ENV:?TARGET_ENV is required}"
: "${RELEASE_ID:?RELEASE_ID is required}"
: "${ALLOW_DESTROY_FILE_INPUT:?ALLOW_DESTROY_FILE_INPUT is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

root="${ENV_ROOT:-$REPO_ROOT/terraform/envs/$TARGET_ENV}"
artifact="delivery-platform-${TARGET_ENV}-${RELEASE_ID}-plan"
artifact_dir="$root/review-artifact"
mkdir -p "$artifact_dir"
cp "$root/backend.hcl" "$root/terraform.auto.tfvars" "$artifact_dir/"
cp "$root/tfplan" "$root/tfplan.sha256" "$root/tfplan.txt" "$root/tfplan.json" "$artifact_dir/"
cp -r "$root/policy-results" "$root/cost-policy-results" "$root/risk-results" "$artifact_dir/"
[[ -f "$root/promotion-evidence.json" ]] && cp "$root/promotion-evidence.json" "$artifact_dir/"
[[ -f "$root/source-workflow-run-verification.json" ]] && cp "$root/source-workflow-run-verification.json" "$artifact_dir/"

if [[ "$ALLOW_DESTROY_FILE_INPUT" != "none" ]]; then
  exception_file="$REPO_ROOT/$ALLOW_DESTROY_FILE_INPUT"
  [[ -s "$exception_file" ]] || { echo "Reviewed destroy exception not found: $ALLOW_DESTROY_FILE_INPUT" >&2; exit 64; }
  cp "$exception_file" "$artifact_dir/allow-destroy.json"
  "$REPO_ROOT/scripts/destroy-exception-evidence.sh" create \
    "$root/tfplan" "$root/tfplan.sha256" "$exception_file" "$ALLOW_DESTROY_FILE_INPUT" \
    "$artifact_dir/destroy-exception-evidence.json"
fi

echo "artifact_name=$artifact" >> "$GITHUB_OUTPUT"
