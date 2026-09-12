#!/usr/bin/env bash
# Pushes the current branch and waits for the "App Build" GitHub Actions
# workflow run for the current commit, then streams its result. See
# scripts/ci-test.sh for why this project verifies Swift/Xcode builds via
# CI instead of locally.
#
# Usage: scripts/ci-app-build.sh
set -euo pipefail

GH="${GH:-$(command -v gh || true)}"
if [ -z "$GH" ] && [ -x "/c/Program Files/GitHub CLI/gh.exe" ]; then
  GH="/c/Program Files/GitHub CLI/gh.exe"
fi
if [ -z "$GH" ]; then
  echo "FAIL: gh CLI not found. Install it or set GH=/path/to/gh" >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "FAIL: uncommitted changes present — commit before running (this script tests HEAD, not your working tree)" >&2
  exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
SHA=$(git rev-parse HEAD)

echo "Pushing $BRANCH ($SHA) ..."
git push -u origin "$BRANCH"

echo "Waiting for the CI run for $SHA to appear ..."
RUN_ID=""
for i in $(seq 1 30); do
  RUN_ID=$("$GH" run list --workflow app-build.yml --branch "$BRANCH" --limit 5 \
    --json databaseId,headSha,status -q "[.[] | select(.headSha == \"$SHA\")][0].databaseId" 2>/dev/null || true)
  if [ -n "$RUN_ID" ] && [ "$RUN_ID" != "null" ]; then
    break
  fi
  sleep 5
done

if [ -z "$RUN_ID" ] || [ "$RUN_ID" = "null" ]; then
  echo "FAIL: no CI run found for $SHA after 150s" >&2
  exit 1
fi

echo "Watching run $RUN_ID ..."
"$GH" run watch "$RUN_ID" --exit-status
