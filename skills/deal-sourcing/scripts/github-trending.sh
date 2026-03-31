#!/bin/bash
# github-trending.sh — Scan GitHub for trending investment opportunities via Search API
# Usage: ./github-trending.sh [--json] [--language python|rust|typescript]
#
# Uses GitHub Search API (JSON) — no HTML scraping, no re module.

set -e

OUTPUT_JSON=""
LANGUAGE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --json) OUTPUT_JSON=1; shift ;;
        --language) LANGUAGE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Date cutoff: repos created in the last 7 days (broad net for "trending")
SINCE=$(date -u -v-7d '+%Y-%m-%d' 2>/dev/null || date -u -d '7 days ago' '+%Y-%m-%d')

# Build query
QUERY="created:>${SINCE}+sort:stars"
if [ -n "$LANGUAGE" ]; then
    QUERY="${QUERY}+language:${LANGUAGE}"
fi

API_URL="https://api.github.com/search/repositories?q=${QUERY}&sort=stars&order=desc&per_page=50"

python3 -W ignore -E -s << PYEOF
import os, json, sys, urllib.request, urllib.parse
from datetime import datetime, timezone

os.environ["PYTHONIOENCODING"] = "utf-8"

api_url = "$API_URL"
output_json = "$OUTPUT_JSON"

headers = {
    'User-Agent': 'deal-sourcing-bot/1.0',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
}

# Inject token if available
gh_token = os.environ.get('GITHUB_TOKEN', '')
if gh_token:
    headers['Authorization'] = f'Bearer {gh_token}'

try:
    req = urllib.request.Request(api_url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode('utf-8'))
except Exception as e:
    if output_json:
        print(json.dumps([]))
    else:
        print(f"Error fetching GitHub API: {e}")
    sys.exit(1)

items = data.get('items', [])

AI_KEYWORDS = [
    'ai', 'llm', 'agent', 'gpt', 'claude', 'openai', 'langchain',
    'vector', 'embedding', 'rag', 'inference', 'ml', 'neural',
    'automation', 'workflow', 'api', 'sdk', 'framework', 'tool',
    'copilot', 'assistant', 'chat', 'prompt',
]

VC_KEYWORDS = [
    'venture', 'vc', 'fund', 'deal-sourcing', 'deal sourcing',
    'due diligence', 'diligence', 'portfolio', 'alternative data',
    'alternative-data', 'investment intelligence', 'fund intelligence',
    'startup intelligence', 'pitch', 'cap table', 'term sheet',
    'crunchbase', 'dealflow', 'deal flow', 'mosaic', 'signal',
]

repos = []
for item in items:
    full_name   = item.get('full_name', '')
    description = (item.get('description') or '')[:300]
    stars       = item.get('stargazers_count', 0)
    language    = item.get('language') or 'Unknown'
    url         = item.get('html_url', f'https://github.com/{full_name}')
    pushed_at   = item.get('pushed_at', '')

    # Approximate "stars today" — not available from search API, use total as proxy signal
    # We'll score on total stars since these are freshly created repos
    score = 0
    signals = []

    text = (description + ' ' + full_name).lower()

    # Stars velocity proxy (max 30 pts)
    if stars >= 1000:
        score += 30; signals.append(f"🔥 {stars} stars")
    elif stars >= 500:
        score += 22; signals.append(f"⭐ {stars} stars")
    elif stars >= 200:
        score += 15; signals.append(f"📈 {stars} stars")
    elif stars >= 50:
        score += 8;  signals.append(f"↗️ {stars} stars")

    # AI relevance (max 25 pts)
    ai_matches = [kw for kw in AI_KEYWORDS if kw in text]
    if len(ai_matches) >= 3:
        score += 25; signals.append(f"🤖 AI: {', '.join(ai_matches[:3])}")
    elif ai_matches:
        score += 15; signals.append(f"🤖 AI: {', '.join(ai_matches[:2])}")

    # VC/Fund-ops relevance (bonus 20 pts)
    vc_matches = [kw for kw in VC_KEYWORDS if kw in text]
    if vc_matches:
        score += 20; signals.append(f"💼 VC/Fund: {', '.join(vc_matches[:2])}")

    # Early stage bonus (max 20 pts) — new repos with fast growth
    if stars < 500:
        score += 20; signals.append("🌱 Early (<500 stars)")
    elif stars < 2000:
        score += 10; signals.append("📊 Growing")

    # Language bonus (max 10 pts)
    if language in ['Python', 'TypeScript', 'Rust', 'Go']:
        score += 10; signals.append(f"💻 {language}")

    repos.append({
        'repo':        full_name,
        'url':         url,
        'description': description,
        'total_stars': stars,
        'language':    language,
        'pushed_at':   pushed_at,
        'score':       min(score, 100),
        'signals':     signals,
    })

repos.sort(key=lambda x: -x['score'])

if output_json:
    print(json.dumps(repos, indent=2, ensure_ascii=False))
else:
    print('🔍 GitHub Trending (Search API) — Investment Scan')
    print('=' * 52)
    for r in repos[:15]:
        emoji = '🔴' if r['score'] >= 70 else '🟡' if r['score'] >= 50 else '⚪'
        print(f"\n{emoji} [{r['score']}] {r['repo']}")
        desc = r['description']
        if len(desc) > 80:
            desc = desc[:80] + '...'
        print(f"   {desc}")
        print(f"   Signals: {' | '.join(r['signals'])}")
    interesting = len([r for r in repos if r['score'] >= 50])
    print(f"\n📊 Total: {len(repos)} repos scanned, {interesting} interesting")
PYEOF
