#!/usr/bin/env bash
set -Eeuo pipefail

: "${TARGET_ENV:?TARGET_ENV is required}"
: "${RELEASE_ID:?RELEASE_ID is required}"
: "${SOURCE_ENV:?SOURCE_ENV is required}"
: "${SOURCE_WORKFLOW_RUN_URL:?SOURCE_WORKFLOW_RUN_URL is required}"
: "${CONFIRM_APPLY:?CONFIRM_APPLY is required}"
: "${ALLOW_DESTROY_FILE_INPUT:?ALLOW_DESTROY_FILE_INPUT is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

case "$TARGET_ENV" in dev|stage|prod) ;; *) echo "target_env must be dev, stage, or prod" >&2; exit 64 ;; esac

if [[ "$CONFIRM_APPLY" != "APPLY" ]]; then
  echo "confirm_apply must be APPLY" >&2
  exit 64
fi
if [[ ! "$RELEASE_ID" =~ ^[A-Za-z0-9._-]{1,80}$ ]]; then
  echo "release_id must contain only letters, numbers, dot, underscore, and dash; max length 80" >&2
  exit 64
fi
if [[ "$ALLOW_DESTROY_FILE_INPUT" != "none" && ! "$ALLOW_DESTROY_FILE_INPUT" =~ ^policies/approved-destroy/[A-Za-z0-9._-]+\.json$ ]]; then
  echo "allow_destroy_file must be none or a JSON file under policies/approved-destroy/" >&2
  exit 64
fi

case "$TARGET_ENV" in
  dev)
    [[ "$SOURCE_ENV" == "none" ]] || { echo "dev promotion must use source_env=none" >&2; exit 64; }
    [[ "$SOURCE_WORKFLOW_RUN_URL" == "none" ]] || { echo "dev promotion must use source_workflow_run_url=none" >&2; exit 64; }
    ;;
  stage)
    [[ "$SOURCE_ENV" == "dev" ]] || { echo "stage promotion must use source_env=dev" >&2; exit 64; }
    ;;
  prod)
    [[ "$SOURCE_ENV" == "stage" ]] || { echo "prod promotion must use source_env=stage" >&2; exit 64; }
    ;;
esac

if [[ "$TARGET_ENV" != "dev" ]]; then
  source_url_prefix="https://github.com/${GITHUB_REPOSITORY}/actions/runs/"
  source_run_id="${SOURCE_WORKFLOW_RUN_URL#"$source_url_prefix"}"
  if [[ "$SOURCE_WORKFLOW_RUN_URL" != "$source_url_prefix$source_run_id" || ! "$source_run_id" =~ ^[0-9]+$ ]]; then
    echo "source_workflow_run_url must be the canonical GitHub Actions run URL for this repository" >&2
    exit 64
  fi
fi

echo "target_env=$TARGET_ENV" >> "$GITHUB_OUTPUT"
