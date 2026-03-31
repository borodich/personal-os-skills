#!/bin/bash
# daily-scan-ollama-v2.sh — Simplified Ollama deal sourcing

set -e

SCRIPT_DIR="$(dirname "$0")"
DATE=$(date +"%Y-%m-%d")
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

echo "[ollama] Starting scan for $DATE..."

# Collect data
GITHUB_RAW=$("$SCRIPT_DIR/github-trending.sh" 2>&1 | grep -v '^\[' || true)
HN_RAW=$("$SCRIPT_DIR/hackernews-showhn.sh" 2>&1 | grep -v '^\[' || true)

# Save raw
RAW_FILE="/tmp/deal-raw-$TIMESTAMP.txt"
cat > "$RAW_FILE" << RAWEOF
=== GITHUB TRENDING ===
$GITHUB_RAW

=== HACKERNEWS SHOW HN ===
$HN_RAW
RAWEOF

echo "[ollama] Raw data: $RAW_FILE"

# Build prompt with conservative calibration
PROMPT="You are a CONSERVATIVE venture capital analyst specializing in early-stage AI/ML investments.

Score each project 0-100 for EARLY-STAGE INVESTMENT potential.

SCORING CALIBRATION (be HARSH):
- 90-100: EXCEPTIONAL — Top 1% of all startups. Unicorn potential. You would invest \$1M+ TODAY.
- 80-89: STRONG — Clear product-market fit, strong founding team, proven traction.
- 70-79: PROMISING — Interesting signals but needs validation. Worth watching closely.
- 60-69: WATCHLIST — Some potential, monitor for growth.
- 50-59: PASS — Not enough investment signals yet.
- <50: REJECT — Does not meet investment criteria.

IMPORTANT: Most projects should score 60-75. Only score 80+ if truly exceptional. Score 90+ VERY rarely.

Criteria:
1. Stars velocity (growing fast vs plateaued)
2. Founder/team track record (check contributors)
3. AI/agent relevance (core to our thesis)
4. Early stage signals (<3 months, no big funding yet)
5. Building in public (active community, docs, marketing)

Output VALID JSON only:
{
  \"alerts\": [
    {\"name\":\"project-name\", \"score\":75, \"source\":\"github\", \"url\":\"https://...\", \"reasoning\":\"Why investment-worthy\"}
  ],
  \"watchlist\": [...]
}

DATA TO ANALYZE:
$(cat "$RAW_FILE")"

# Call Ollama
echo "[ollama] Calling qwen2.5-coder:32b-instruct..."
RESPONSE=$(curl -s http://localhost:11434/api/generate -d "$(cat << CURLEOF
{
  "model": "qwen2.5-coder:32b-instruct-q4_K_M",
  "prompt": $(echo "$PROMPT" | jq -Rs .),
  "stream": false,
  "options": {"temperature": 0.3, "num_predict": 2000}
}
CURLEOF
)" | jq -r '.response' 2>&1)

# Extract JSON using python (handles multiline)
RESULTS=$(echo "$RESPONSE" | python3 -c "
import sys, re
text = sys.stdin.read()
# Remove markdown blocks
text = text.replace('\`\`\`json', '').replace('\`\`\`', '')
# Find first { and last }
start = text.find('{')
end = text.rfind('}')
if start >= 0 and end > start:
    print(text[start:end+1])
")

if [ -z "$RESULTS" ]; then
    echo "[ollama] ERROR: No JSON in response"
    echo "$RESPONSE" | head -20
    exit 1
fi

# Save
RESULTS_FILE="/tmp/deal-ollama-$TIMESTAMP.json"
echo "$RESULTS" > "$RESULTS_FILE"

# Print summary
python3 - "$RESULTS_FILE" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
alerts = data.get('alerts', [])
watchlist = data.get('watchlist', [])
print(f"\n📊 Ollama Scan ({len(alerts)} alerts, {len(watchlist)} watchlist)")
print("=" * 50)
print("\n🔴 ALERTS:")
for a in alerts[:5]:
    print(f"  [{a.get('score',0)}] {a.get('name','')[:50]}")
print(f"\n🟡 WATCHLIST:")
for w in watchlist[:5]:
    print(f"  [{w.get('score',0)}] {w.get('name','')[:50]}")
PYEOF

echo ""
echo "✅ Saved: $RESULTS_FILE"
echo "🔍 Compare with: /tmp/deal-sourcing-sonnet-*"
