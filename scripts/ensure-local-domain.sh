#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="$(tr -d '[:space:]' < "$ROOT/.local-domain")"
MARKER="# cctv-local-domain"

if [[ "$DOMAIN" != "cctv.local" ]]; then
	printf 'error: expected cctv.local, found %s\n' "$DOMAIN" >&2
	exit 1
fi

if awk -v marker="$MARKER" '
	index($0, marker) && $1 == "127.0.0.1" { found = 1 }
	END { exit found ? 0 : 1 }
' /etc/hosts; then
	printf '%s already resolves to 127.0.0.1\n' "$DOMAIN"
	exit 0
fi

if [[ "${DANNIFY_HOSTS_FILE:-}" == "" && "$EUID" -ne 0 ]]; then
	printf 'manual step required: add "127.0.0.1 %s %s" to /etc/hosts\n' "$DOMAIN" "$MARKER" >&2
	exit 2
fi

HOSTS_FILE="${DANNIFY_HOSTS_FILE:-/etc/hosts}"
printf '127.0.0.1\t%s\t%s\n' "$DOMAIN" "$MARKER" >> "$HOSTS_FILE"
printf 'Added %s -> 127.0.0.1\n' "$DOMAIN"
