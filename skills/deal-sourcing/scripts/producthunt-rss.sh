#!/bin/bash
# producthunt-rss.sh — Scan Product Hunt via RSS feed
# URL: https://www.producthunt.com/feed (Atom XML)
# Usage: ./producthunt-rss.sh [--json]

set -e

CACHE_DIR="$HOME/.cache/deal-sourcing"
CACHE_FILE="$CACHE_DIR/ph-seen.txt"
mkdir -p "$CACHE_DIR"
touch "$CACHE_FILE"

RSS_URL="https://www.producthunt.com/feed"

RSS=$(curl -s --max-time 15 -A "Mozilla/5.0 (compatible; AINative-Scanner/1.0)" "$RSS_URL")

if [[ -z "$RSS" ]]; then
  echo '[]'
  exit 0
fi

echo "$RSS" | python3 /Users/abserver/clawd/workspaces/vc/skills/deal-sourcing/scripts/_ph_rss_parser.py "$CACHE_FILE"
