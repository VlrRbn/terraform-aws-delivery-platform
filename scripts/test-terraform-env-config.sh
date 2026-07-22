#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

write_config() {
  local target_env="$1"
  local env_dir="$2"
  local region="${3:-eu-west-1}"

  AWS_REGION="$region" \
    TF_STATE_BUCKET="delivery-platform-test-state" \
    TF_WEB_AMI_ID="ami-0123456789abcdef0" \
    TF_SSM_PROXY_AMI_ID="ami-0123456789abcdef0" \
    TF_ENV_DIR="$env_dir" \
    "$SCRIPT_DIR/write-terraform-env-files.sh" "$target_env" >/dev/null
}

expect_rejected() {
  local name="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    echo "Expected config validation to reject: $name" >&2
    exit 1
  fi
}

for target_env in dev stage prod; do
  env_dir="$TEST_ROOT/$target_env"
  write_config "$target_env" "$env_dir"
  TF_STATE_BUCKET="delivery-platform-test-state" \
    "$SCRIPT_DIR/validate-terraform-env-config.sh" "$target_env" "$env_dir" >/dev/null
done

wrong_key_dir="$TEST_ROOT/wrong-key"
write_config dev "$wrong_key_dir"
sed -i 's#delivery-platform/dev/full/terraform.tfstate#delivery-platform/prod/full/terraform.tfstate#' "$wrong_key_dir/backend.hcl"
expect_rejected wrong_backend_key env TF_STATE_BUCKET="delivery-platform-test-state" \
  "$SCRIPT_DIR/validate-terraform-env-config.sh" dev "$wrong_key_dir"

wrong_bucket_dir="$TEST_ROOT/wrong-bucket"
write_config dev "$wrong_bucket_dir"
sed -i 's/delivery-platform-test-state/another-state-bucket/' "$wrong_bucket_dir/backend.hcl"
expect_rejected wrong_backend_bucket env TF_STATE_BUCKET="delivery-platform-test-state" \
  "$SCRIPT_DIR/validate-terraform-env-config.sh" dev "$wrong_bucket_dir"

wrong_region_dir="$TEST_ROOT/wrong-region"
write_config dev "$wrong_region_dir" us-east-1
expect_rejected wrong_region env TF_STATE_BUCKET="delivery-platform-test-state" \
  "$SCRIPT_DIR/validate-terraform-env-config.sh" dev "$wrong_region_dir"

wrong_availability_zones_dir="$TEST_ROOT/wrong-availability-zones"
write_config dev "$wrong_availability_zones_dir"
sed -i 's/eu-west-1b/eu-west-1c/' "$wrong_availability_zones_dir/terraform.auto.tfvars"
expect_rejected wrong_availability_zones env TF_STATE_BUCKET="delivery-platform-test-state" \
  "$SCRIPT_DIR/validate-terraform-env-config.sh" dev "$wrong_availability_zones_dir"

echo "terraform environment config tests passed"
