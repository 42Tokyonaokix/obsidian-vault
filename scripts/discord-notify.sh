#!/bin/bash
set -euo pipefail

if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
    echo "Error: DISCORD_WEBHOOK_URL is not set" >&2
    exit 1
fi

if [ -z "${1:-}" ]; then
    echo "Usage: discord-notify.sh <message>" >&2
    exit 1
fi

# Use jq for safe JSON escaping
if command -v jq >/dev/null 2>&1; then
    PAYLOAD=$(jq -n --arg msg "$1" '{content: $msg}')
else
    # Fallback: basic escaping
    MSG=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')
    PAYLOAD="{\"content\": \"${MSG}\"}"
fi

HTTP_CODE=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$DISCORD_WEBHOOK_URL") || {
    echo "Error: curl request failed (network error or timeout)" >&2
    exit 1
}

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
    echo "Error: Discord webhook returned HTTP $HTTP_CODE" >&2
    exit 1
fi
