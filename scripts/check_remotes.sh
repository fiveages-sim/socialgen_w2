#!/usr/bin/env bash
# Fail if a git checkout pushes to Social-Nav.
# Usage: ./scripts/check_remotes.sh /path/to/repo
set -euo pipefail

root="${1:-}"
if [[ -z "${root}" ]]; then
  echo "Usage: $0 /path/to/git/checkout" >&2
  exit 2
fi
if ! git -C "${root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git checkout: ${root}" >&2
  exit 2
fi

origin="$(git -C "${root}" remote get-url origin 2>/dev/null || true)"
echo "origin: ${origin:-<none>}"
if [[ "${origin}" == *Social-Nav/* ]]; then
  echo "Refusing Social-Nav remote. Do not push W2 or FiveAges work here." >&2
  exit 1
fi
echo "OK: origin is not Social-Nav."
