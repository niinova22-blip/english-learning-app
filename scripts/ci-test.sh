#!/usr/bin/env bash
# Pushes the current branch and waits for the GitHub Actions macOS "Swift Tests"
# workflow run for the current commit, then streams its result.
#
# This exists because SwiftData (Apple-only) cannot be built or tested on this
# Windows machine — GitHub Actions macos-latest runners are the verification
# environment for this project's Swift code. Use this instead of `swift test`.
#
# Usage: scripts/ci-test.sh
set -euo pipefail

GH="/c/Program Files/GitHub CLI/gh.exe"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
SHA=$(git rev-parse HEAD)

echo "Pushing $BRANCH ($SHA) ..."
git push -u origin "$BRANCH"

echo "Waiting for the CI run for $SHA to appear ..."
RUN_ID=""
for i in $(seq 1 30); do
  RUN_ID=$("$GH" run list --workflow swift-tests.yml --branch "$BRANCH" --limit 5 \
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
