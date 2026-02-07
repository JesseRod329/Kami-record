#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

base_ref="${GITHUB_BASE_REF:-}"
head_ref="${GITHUB_HEAD_REF:-}"

if [ -n "$base_ref" ] && [ -n "$head_ref" ]; then
  git fetch --no-tags --prune --depth=1 origin "$base_ref" >/dev/null 2>&1 || true
  changed=$(git diff --name-only "origin/$base_ref...HEAD")
else
  changed=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || true)
fi

if [ -z "$changed" ]; then
  echo "No changed files detected for guardrails"
  exit 0
fi

needs_changelog="false"
while IFS= read -r file; do
  case "$file" in
    *.swift|KAMIBotApp/Package.swift|Packages/*/Package.swift)
      needs_changelog="true"
      ;;
  esac
done <<< "$changed"

if [ "$needs_changelog" = "true" ]; then
  if ! grep -q "^## \[Unreleased\]" CHANGELOG.md; then
    echo "CHANGELOG.md must include an [Unreleased] section"
    exit 1
  fi
fi

if echo "$changed" | grep -E "KAMIBotApp/Package.swift|Packages/.*/Package.swift" >/dev/null; then
  if ! echo "$changed" | grep -q "docs/dependencies.md"; then
    echo "Dependency manifest changed. Update docs/dependencies.md in the same PR."
    exit 1
  fi
fi

echo "Guardrail checks passed"
