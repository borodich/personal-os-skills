#!/bin/bash
# daily-scan.sh — Run all deal sourcing scanners and save to Obsidian
# Usage: ./daily-scan.sh [--json] [--notify]

set -e

SCRIPT_DIR="$(dirname "$0")"
DATE=$(date +"%Y-%m-%d")
OUTPUT_JSON=""
NOTIFY=""

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --json) OUTPUT_JSON=1; shift ;;
        --notify) NOTIFY=1; shift ;;
        *) shift ;;
    esac
done

# Config
export MIN_SCORE=50
export NOTIFY_THRESHOLD=70

OBSIDIAN_DIR="${OBSIDIAN_PATH:-$HOME/clawd/workspaces/vc}"
MIN_SCORE="${MIN_SCORE:-50}"
NOTIFY_THRESHOLD="${NOTIFY_THRESHOLD:-70}"

mkdir -p "$OBSIDIAN_DIR"

echo "[daily-scan] Starting scan for $DATE..." >&2

# Run scanners
echo "[daily-scan] Scanning GitHub Trending..." >&2
GITHUB_RESULTS=$(echo $("$SCRIPT_DIR/github-trending.sh" --json 2>/dev/null || echo "[]") | sed 's/\"/\\\"/g')

echo "[daily-scan] Scanning HackerNews Show HN..." >&2
HN_RESULTS=$(echo $("$SCRIPT_DIR/hackernews-showhn.sh" --json 2>/dev/null || echo "[]") | sed 's/\"/\\\"/g')

echo "GITHUB_RESULTS: $GITHUB_RESULTS" > ~/clawd/github_results.txt
echo "HN_RESULTS: $HN_RESULTS" > ~/clawd/hn_results.txt

echo "[daily-scan] Scanning Product Hunt RSS..." >&2
PH_RESULTS=$(curl -s --max-time 15 "https://www.producthunt.com/feed" | python3 "$SCRIPT_DIR/_ph_rss_parser.py" 2>/dev/null || echo "[]")
echo "PH_RESULTS done: $(echo $PH_RESULTS | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null) items" >&2
COMBINED=$(python3 -W ignore -E -s << PYEOF
import os
os.environ["PYTHONIOENCODING"] = "utf-8"
import json

from datetime import datetime

try:
    github = json.loads($GITHUB_RESULTS)
except json.JSONDecodeError:
    github = []

try:
    try:
        hackernews = json.loads($HN_RESULTS)
    except json.JSONDecodeError:
        # If it's not valid JSON, assume it's a list of numbers
        try:
            hackernews = json.loads(f'[{$HN_RESULTS}]')
        except json.JSONDecodeError:
            hackernews = []

try:
    producthunt = json.loads("""$PH_RESULTS""")
except:
    producthunt = []

min_score = $MIN_SCORE
notify_threshold = $NOTIFY_THRESHOLD

results = {
    'date': '$DATE',
    'github': [],
    'hackernews': [],
    'alerts': [],
    'watchlist': [],
    'producthunt': []
}

# Process GitHub
for repo in github:
    score = repo.get('score', 0)
    if score >= min_score:
        item = {
            'source': 'github',
            'name': repo['repo'],
            'url': repo['url'],
            'score': score,
            'signals': repo.get('signals', []),
            'description': repo.get('description', ''),
            'extra': {
                'stars_today': repo.get('stars_today', 0),
                'total_stars': repo.get('total_stars', 0),
                'language': repo.get('language', '')
            }
        }
        results['github'].append(item)
        if score >= notify_threshold:
            results['alerts'].append(item)
        else:
            results['watchlist'].append(item)

# Process Product Hunt RSS
for ph in producthunt:
    score = ph.get('score', 0)
    if score >= min_score:
        item = {
            'source': 'product_hunt',
            'name': ph.get('title', ''),
            'url': ph.get('url', ''),
            'score': score,
            'signals': ph.get('reasons', []),
            'description': ph.get('description', ''),
            'extra': {}
        }
        results['producthunt'].append(item)
        if score >= notify_threshold:
            results['alerts'].append(item)
        else:
            results['watchlist'].append(item)

# Process HackerNews
for story in hackernews:
    score = story.get('investment_score', 0)
    if score >= min_score:
        item = {
            'source': 'hackernews',
            'name': story['title'],
            'url': story.get('url', story['hn_url']),
            'hn_url': story['hn_url'],
            'score': score,
            'signals': story.get('signals', []),
            'description': '',
            'extra': {
                'hn_score': story.get('score', 0),
                'comments': story.get('comments', 0),
                'by': story.get('by', '')
            }
        }
        results['hackernews'].append(item)
        if score >= notify_threshold:
            results['alerts'].append(item)
        else:
            results['watchlist'].append(item)

# Sort by score
results['alerts'].sort(key=lambda x: -x['score'])
results['watchlist'].sort(key=lambda x: -x['score'])

print(json.dumps(results, indent=2))
PYEOF
)

# Save to Obsidian
# save_to_obsidian
    python3 -W ignore -E -s << PYEOF
import os
os.environ["PYTHONIOENCODING"] = "utf-8"

def clean_text(text):
    return text.encode('utf-16', 'surrogatepass').decode('utf-16').encode('utf-8', 'ignore').decode('utf-8')

import json


import os
from datetime import datetime

results = $COMBINED
obsidian_dir = "$OBSIDIAN_DIR"
date = "$DATE"

# Create daily scan summary
summary_path = os.path.join(obsidian_dir, f"{date}-scan.md")

md = f"""---
type: daily-scan
date: {date}
alerts: {len(results['alerts'])}
watchlist: {len(results['watchlist'])}
---

# Deal Sourcing Scan — {date}

## 🔴 Alerts (Score ≥ 70)

"""

if results['alerts']:
    for item in results['alerts']:
        md += f"### [{item['score']}] {item['name']}\n"
        md += f"- **Source:** {item['source']}\n"
        md += f"- **URL:** {item['url']}\n"
        md += f"- **Signals:** {', '.join(item['signals'])}\n"
        if item['description']:
            md += f"- **Description:** {item['description'][:200]}\n"
        md += f"- **Status:** #new\n\n"
else:
    md += "_No high-score projects today_\n\n"

md += """## 🟡 Watchlist (Score 50-69)

"""

if results['watchlist']:
    for item in results['watchlist'][:10]:
        md += f"- [{item['score']}] **{item['name']}** ({item['source']}) — {', '.join(item['signals'][:2])}\n"
else:
    md += "_No watchlist items today_\n"

md += f"""

---

## Stats

- GitHub Trending: {len(results['github'])} interesting
- HackerNews Show HN: {len(results['hackernews'])} interesting
- Total Alerts: {len(results['alerts'])}
- Total Watchlist: {len(results['watchlist'])}

_Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}_
"""

with open(summary_path, 'w') as f:
    f.write(clean_text(md))

print(f"Saved to: {summary_path}")

# Create individual files for alerts
for item in results['alerts']:
    safe_name = item['name'].replace('/', '-').replace(' ', '-')[:50]
    item_path = os.path.join(obsidian_dir, f"{date}-{safe_name}.md")
    
    item_md = f"""---
source: {item['source']}
score: {item['score']}
date_found: {date}
status: new
url: {item['url']}
---

# {item['name']}

**Score:** {item['score']}/100
**Source:** {item['source']}
**URL:** {item['url']}

## Signals

"""
    for signal in item['signals']:
        item_md += f"- {signal}\n"
    
    if item['description']:
        item_md += f"\n## Description\n\n{item['description']}\n"
    
    if item['source'] == 'github':
        extra = item.get('extra', {})
        item_md += f"""
## GitHub Stats

- Stars today: {extra.get('stars_today', 'N/A')}
- Total stars: {extra.get('total_stars', 'N/A')}
- Language: {extra.get('language', 'N/A')}
"""
    elif item['source'] == 'hackernews':
        extra = item.get('extra', {})
        item_md += f"""
## HackerNews Stats

- HN Score: {extra.get('hn_score', 'N/A')}
- Comments: {extra.get('comments', 'N/A')}
- By: @{extra.get('by', 'N/A')}
- HN Link: {item.get('hn_url', '')}
"""
    
    item_md += """
## Next Steps

- [ ] Research founder/team background
- [ ] Check for existing funding
- [ ] Analyze competition
- [ ] Draft outreach message
- [ ] Schedule call
"""
    
    with open(item_path, 'w') as f:
        f.write(clean_text(item_md))

PYEOF
# Output
if [ -n "$OUTPUT_JSON" ]; then
    echo "$COMBINED"
else
#    save_to_obsidian
    
    # Print summary
    echo "$COMBINED" | python3 -c "
import json, sys
r = json.load(sys.stdin)
print(f'''
📊 Daily Scan Complete — {r['date']}
{'=' * 40}

🔴 ALERTS ({len(r['alerts'])}):''')
for a in r['alerts'][:5]:
    print(f\"  [{a['score']}] {a['name'][:50]}\")

print(f'''
🟡 WATCHLIST ({len(r['watchlist'])}):''')
for w in r['watchlist'][:5]:
    print(f\"  [{w['score']}] {w['name'][:50]}\")

print(f'''
📁 Saved to Obsidian
''')
"
fi

# Notify if requested and there are alerts
if [ -n "$NOTIFY" ]; then
    ALERT_COUNT=$(echo "$COMBINED" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['alerts']))")
    if [ "$ALERT_COUNT" -gt 0 ]; then
        echo "[daily-scan] Sending notification for $ALERT_COUNT alerts..." >&2
        # Notification would be sent via OpenClaw message tool
        echo "NOTIFY:$ALERT_COUNT alerts found in daily scan"
    fi
echo "$COMBINED" > ~/clawd/workspaces/vc/daily_scan_output.txt

# ── Deal DB: auto-save results ──────────────────────────────────────────────
DEAL_SAVE="$HOME/clawd/scripts/deal-save.sh"
if [ -x "$DEAL_SAVE" ]; then
    echo "[daily-scan] Saving to deal DB..." >&2
    # Convert combined results to deal-save format
    SAVE_PAYLOAD=$(echo "$COMBINED" | python3 -c "
import json, sys
r = json.load(sys.stdin)
projects = []
for item in r.get('alerts', []) + r.get('watchlist', []):
    p = {
        'name': item['name'],
        'github_url': item['url'] if item['source'] == 'github' else '',
        'description': item.get('description', ''),
        'source': item['source'],
        'score': item['score'],
        'author': item.get('extra', {}).get('by', ''),
        'language': item.get('extra', {}).get('language', ''),
        'initial_stars': item.get('extra', {}).get('total_stars', 0),
        'stars_per_day': item.get('extra', {}).get('stars_today', 0),
    }
    projects.append(p)
print(json.dumps({'projects': projects}))
" 2>/dev/null)
    echo "$SAVE_PAYLOAD" | "$DEAL_SAVE" 2>&1 | grep -E '(✅|⏭️|Done)' >&2 || true
fi
