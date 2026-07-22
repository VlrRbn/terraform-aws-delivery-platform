#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_ENV="${1:-}"
ENV_DIR="${2:-}"

case "$TARGET_ENV" in
  dev|stage|prod) ;;
  *) echo "Usage: validate-terraform-env-config.sh <dev|stage|prod> [env-dir]" >&2; exit 64 ;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENV_DIR="${ENV_DIR:-${PROJECT_DIR}/terraform/envs/${TARGET_ENV}}"
BACKEND_FILE="${ENV_DIR}/backend.hcl"
TFVARS_FILE="${ENV_DIR}/terraform.auto.tfvars"

for file in "$BACKEND_FILE" "$TFVARS_FILE"; do
  if [[ ! -f "$file" ]]; then
    echo "Required generated Terraform config not found: $file" >&2
    exit 64
  fi
done

read_string_assignment() {
  local field="$1"
  local file="$2"

  awk -v field="$field" '
    $1 == field && $2 == "=" {
      value = $0
      sub(/^[^=]*=[[:space:]]*"/, "", value)
      sub(/"[[:space:]]*$/, "", value)
      print value
    }
  ' "$file"
}

assert_assignment() {
  local field="$1"
  local expected="$2"
  local file="$3"
  local actual

  actual="$(read_string_assignment "$field" "$file")"
  if [[ "$actual" != "$expected" ]]; then
    echo "Unsafe Terraform config: $file must contain exactly $field = \"$expected\"" >&2
    exit 64
  fi
}

assert_exact_line() {
  local expected="$1"
  local file="$2"

  if [[ "$(grep -Fxc -- "$expected" "$file")" -ne 1 ]]; then
    echo "Unsafe Terraform config: $file must contain exactly one line: $expected" >&2
    exit 64
  fi
}

expected_key="delivery-platform/${TARGET_ENV}/full/terraform.tfstate"
expected_project="delivery-platform-${TARGET_ENV}"

assert_assignment key "$expected_key" "$BACKEND_FILE"
assert_assignment region "eu-west-1" "$BACKEND_FILE"

bucket="$(read_string_assignment bucket "$BACKEND_FILE")"
if [[ -z "$bucket" || "$bucket" == *$'\n'* ]]; then
  echo "Unsafe Terraform config: $BACKEND_FILE must contain exactly one non-empty bucket assignment" >&2
  exit 64
fi
if [[ -n "${TF_STATE_BUCKET:-}" && "$bucket" != "$TF_STATE_BUCKET" ]]; then
  echo "Unsafe Terraform config: backend bucket does not match TF_STATE_BUCKET" >&2
  exit 64
fi

assert_assignment aws_region "eu-west-1" "$TFVARS_FILE"
assert_assignment project_name "$expected_project" "$TFVARS_FILE"
assert_assignment environment "$TARGET_ENV" "$TFVARS_FILE"
assert_assignment tf_state_key "$expected_key" "$TFVARS_FILE"
assert_exact_line 'availability_zones   = ["eu-west-1a", "eu-west-1b"]' "$TFVARS_FILE"

echo "Validated Terraform config for ${TARGET_ENV}: backend key, region, project, environment, and Availability Zones match."
