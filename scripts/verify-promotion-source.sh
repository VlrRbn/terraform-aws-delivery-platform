#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "Usage: verify-promotion-source.sh <run|manifest> [promotion-manifest.json]" >&2
  exit 64
}

mode="${1:-}"
case "$mode" in
  run)
    : "${SOURCE_WORKFLOW_RUN_URL:?SOURCE_WORKFLOW_RUN_URL is required}"
    : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
    : "${GITHUB_SHA:?GITHUB_SHA is required}"
    : "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
    source_url_prefix="https://github.com/${GITHUB_REPOSITORY}/actions/runs/"
    run_id="${SOURCE_WORKFLOW_RUN_URL#"$source_url_prefix"}"
    if [[ "$SOURCE_WORKFLOW_RUN_URL" != "$source_url_prefix$run_id" || ! "$run_id" =~ ^[0-9]+$ ]]; then
      echo "source_workflow_run_url must be the canonical GitHub Actions run URL for this repository" >&2
      exit 64
    fi
    run_json="$("${GH_BIN:-gh}" api "repos/${GITHUB_REPOSITORY}/actions/runs/${run_id}")"
    status="$(jq -r '.status // ""' <<<"$run_json")"
    conclusion="$(jq -r '.conclusion // ""' <<<"$run_json")"
    head_sha="$(jq -r '.head_sha // ""' <<<"$run_json")"
    html_url="$(jq -r '.html_url // ""' <<<"$run_json")"
    workflow_name="$(jq -r '.name // ""' <<<"$run_json")"
    workflow_path="$(jq -r '.path // ""' <<<"$run_json")"
    display_title="$(jq -r '.display_title // ""' <<<"$run_json")"

    [[ "$status" == "completed" && "$conclusion" == "success" ]] || {
      echo "source workflow run is not completed successfully: status=$status conclusion=$conclusion" >&2
      exit 64
    }
    [[ "$head_sha" == "$GITHUB_SHA" ]] || {
      echo "source workflow run SHA does not match this workflow SHA: source=$head_sha current=$GITHUB_SHA" >&2
      exit 64
    }
    [[ "$workflow_path" == ".github/workflows/promote.yml" ]] || {
      echo "source workflow run must be promote: name=$workflow_name path=$workflow_path" >&2
      exit 64
    }

    {
      echo "run_id=$run_id"
      echo "head_sha=$head_sha"
      echo "html_url=$html_url"
      echo "conclusion=$conclusion"
      echo "workflow_name=$workflow_name"
      echo "workflow_path=$workflow_path"
      echo "display_title=$display_title"
    } >> "$GITHUB_OUTPUT"
    ;;
  manifest)
    manifest="${2:-/tmp/delivery-platform-source-apply/promotion-manifest.json}"
    : "${RELEASE_ID:?RELEASE_ID is required}"
    : "${SOURCE_ENV:?SOURCE_ENV is required}"
    : "${GITHUB_SHA:?GITHUB_SHA is required}"
    : "${SOURCE_WORKFLOW_RUN_URL:?SOURCE_WORKFLOW_RUN_URL is required}"
    [[ -s "$manifest" ]] || { echo "source apply artifact does not contain promotion-manifest.json" >&2; exit 64; }
    jq -e \
      --arg release_id "$RELEASE_ID" \
      --arg source_env "$SOURCE_ENV" \
      --arg commit_sha "$GITHUB_SHA" \
      --arg source_url "$SOURCE_WORKFLOW_RUN_URL" \
      '.release_id == $release_id
       and .target_env == $source_env
       and .commit_sha == $commit_sha
       and .workflow_run_url == $source_url
       and .apply_exitcode == "0"
       and .post_apply_exitcode == "0"
       and .final_status == "PROMOTABLE"' "$manifest" >/dev/null
    ;;
  *) usage ;;
esac
