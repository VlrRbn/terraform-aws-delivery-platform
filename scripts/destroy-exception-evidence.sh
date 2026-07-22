#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  destroy-exception-evidence.sh create PLAN CHECKSUM EXCEPTION REPOSITORY_PATH OUTPUT
  destroy-exception-evidence.sh verify PLAN CHECKSUM EXCEPTION EVIDENCE

Required environment variables:
  GITHUB_SHA  Exact 40-character workflow commit SHA.
  TARGET_ENV  dev, stage, or prod.
  RELEASE_ID  Current workflow release identifier.
USAGE
}

die() {
  echo "destroy exception evidence: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  local label="$2"
  [[ -s "$path" ]] || die "$label is missing or empty: $path"
}

validate_context() {
  [[ "${GITHUB_SHA:-}" =~ ^[0-9a-f]{40}$ ]] || die "GITHUB_SHA must be a full lowercase commit SHA"
  [[ "${TARGET_ENV:-}" =~ ^(dev|stage|prod)$ ]] || die "TARGET_ENV must be dev, stage, or prod"
  [[ "${RELEASE_ID:-}" =~ ^[A-Za-z0-9._-]{1,80}$ ]] || die "RELEASE_ID is invalid"
}

plan_sha256() {
  local plan_file="$1"
  local checksum_file="$2"
  local checksum_lines=()
  local expected_sha
  local actual_sha

  require_file "$plan_file" "plan"
  require_file "$checksum_file" "plan checksum"

  mapfile -t checksum_lines < "$checksum_file"
  ((${#checksum_lines[@]} == 1)) || die "plan checksum must contain exactly one record"
  [[ "${checksum_lines[0]}" =~ ^([0-9a-f]{64})[[:space:]]+[*]?[^[:space:]]+$ ]] || \
    die "plan checksum record is malformed"
  expected_sha="${BASH_REMATCH[1]}"
  actual_sha="$(sha256sum "$plan_file" | awk '{print $1}')"
  [[ "$actual_sha" == "$expected_sha" ]] || die "plan SHA256 does not match the reviewed checksum"

  printf '%s\n' "$actual_sha"
}

validate_exception_binding() {
  local exception_file="$1"
  local expires
  local parsed_expires
  local today_utc
  local max_expires
  require_file "$exception_file" "destroy exception"

  jq -e \
    --arg target_env "$TARGET_ENV" \
    --arg release_id "$RELEASE_ID" \
    '
      type == "object"
      and (keys | sort == ["allowed_addresses", "approved_by", "expires", "reason", "release_id", "target_env"])
      and (.reason | type == "string" and length > 0)
      and (.approved_by | type == "string" and length > 0)
      and .target_env == $target_env
      and .release_id == $release_id
      and (.expires | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))
      and (.allowed_addresses | type == "array" and length > 0)
      and all(.allowed_addresses[]; type == "string" and length > 0 and (contains("*") | not))
    ' "$exception_file" >/dev/null || die "destroy exception does not match workflow bindings"

  expires="$(jq -r '.expires' "$exception_file")"
  parsed_expires="$(date -u -d "$expires" +%F 2>/dev/null)" || \
    die "destroy exception expiry is not a valid calendar date"
  [[ "$parsed_expires" == "$expires" ]] || die "destroy exception expiry is not a valid calendar date"
  today_utc="$(date -u +%F)"
  max_expires="$(date -u -d "${today_utc} + 7 days" +%F)"
  if [[ "$expires" < "$today_utc" ]]; then
    die "destroy exception is expired"
  fi
  if [[ "$expires" > "$max_expires" ]]; then
    die "destroy exception expiry is more than seven days away"
  fi
}

create_evidence() {
  (($# == 5)) || { usage; exit 64; }
  local plan_file="$1"
  local checksum_file="$2"
  local exception_file="$3"
  local repository_path="$4"
  local output_file="$5"
  local plan_sha
  local exception_sha
  local tmp_file

  [[ "$repository_path" =~ ^policies/approved-destroy/[A-Za-z0-9._-]+\.json$ ]] || \
    die "repository exception path is outside policies/approved-destroy"
  validate_exception_binding "$exception_file"
  plan_sha="$(plan_sha256 "$plan_file" "$checksum_file")"
  exception_sha="$(sha256sum "$exception_file" | awk '{print $1}')"

  mkdir -p "$(dirname "$output_file")"
  tmp_file="${output_file}.tmp.$$"
  trap 'rm -f "$tmp_file"' RETURN
  jq -n \
    --arg github_sha "$GITHUB_SHA" \
    --arg tfplan_sha256 "$plan_sha" \
    --arg exception_path "$repository_path" \
    --arg exception_sha256 "$exception_sha" \
    --arg target_env "$TARGET_ENV" \
    --arg release_id "$RELEASE_ID" \
    --slurpfile exception "$exception_file" \
    '{
      schema_version: 1,
      github_sha: $github_sha,
      tfplan_sha256: $tfplan_sha256,
      exception_path: $exception_path,
      exception_sha256: $exception_sha256,
      target_env: $target_env,
      release_id: $release_id,
      expires: $exception[0].expires,
      allowed_addresses: $exception[0].allowed_addresses
    }' > "$tmp_file"
  mv "$tmp_file" "$output_file"
  trap - RETURN
}

verify_evidence() {
  (($# == 4)) || { usage; exit 64; }
  local plan_file="$1"
  local checksum_file="$2"
  local exception_file="$3"
  local evidence_file="$4"
  local plan_sha
  local exception_sha

  validate_exception_binding "$exception_file"
  require_file "$evidence_file" "destroy exception evidence"
  plan_sha="$(plan_sha256 "$plan_file" "$checksum_file")"
  exception_sha="$(sha256sum "$exception_file" | awk '{print $1}')"

  jq -e \
    --arg github_sha "$GITHUB_SHA" \
    --arg tfplan_sha256 "$plan_sha" \
    --arg exception_sha256 "$exception_sha" \
    --arg target_env "$TARGET_ENV" \
    --arg release_id "$RELEASE_ID" \
    --slurpfile exception "$exception_file" \
    '
      type == "object"
      and (keys | sort == [
        "allowed_addresses",
        "exception_path",
        "exception_sha256",
        "expires",
        "github_sha",
        "release_id",
        "schema_version",
        "target_env",
        "tfplan_sha256"
      ])
      and .schema_version == 1
      and .github_sha == $github_sha
      and .tfplan_sha256 == $tfplan_sha256
      and (.exception_path | test("^policies/approved-destroy/[A-Za-z0-9._-]+\\.json$"))
      and .exception_sha256 == $exception_sha256
      and .target_env == $target_env
      and .release_id == $release_id
      and .expires == $exception[0].expires
      and .allowed_addresses == $exception[0].allowed_addresses
    ' "$evidence_file" >/dev/null || die "destroy exception evidence does not match the reviewed plan and workflow"
}

command="${1:-}"
[[ -n "$command" ]] || { usage; exit 64; }
shift
validate_context

case "$command" in
  create) create_evidence "$@" ;;
  verify) verify_evidence "$@" ;;
  *) usage; exit 64 ;;
esac
