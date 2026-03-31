#!/bin/bash
# Vic Deal Sourcing - DGX Qwen 72B (simplified)
# Runs at 6:00 AM daily via cron

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$HOME/clawd/workspaces/vc/deal-sourcing"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$HOME/clawd/logs/deal-sourcing.log"

mkdir -p "$OUTPUT_DIR"

echo "=== Vic Deal Sourcing - DGX Qwen 72B ===" | tee -a "$LOG_FILE"
echo "Time: $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Create scoring task (fetch + analyze in one go)
cat > /tmp/vic-deal-task-$$.py << 'TASK'
#!/usr/bin/env python3
import json
import requests
import sys
from datetime import datetime, timedelta

# Fetch GitHub trending
week_ago = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
url = f"https://api.github.com/search/repositories?q=created:>{week_ago}+stars:>50&sort=stars&order=desc&per_page=10"

try:
    r = requests.get(url, timeout=10)
    r.raise_for_status()
    data = r.json()
    
    projects = []
    for item in data.get('items', [])[:10]:
        projects.append({
            'name': item['name'],
            'url': item['html_url'],
            'stars': item['stargazers_count'],
            'description': item.get('description', ''),
            'language': item.get('language', ''),
            'owner': item['owner']['login']
        })
    
    # Call DGX for scoring
    prompt = f"""You are a CONSERVATIVE VC analyst specialized in early-stage tech investments.

Score these GitHub Trending projects for INVESTMENT POTENTIAL (0-100).

HARSH CALIBRATION:
- 90-100: Exceptional (top 1% - would invest $1M+ today)
- 80-89: Strong (clear PMF, proven team, good traction)
- 70-79: Promising (interesting but needs validation)
- 60-69: Watchlist (monitor for growth signals)
- 50-59: Pass (not ready for investment)
- <50: Reject

Projects:
{json.dumps(projects, indent=2)}

For EACH project output:
{{"name": "ProjectName", "score": 75, "reasoning": "Brief reason (1-2 sentences)", "thesis": "Investment angle or pass reason"}}

Output valid JSON array. Be HARSH - most projects should be 50-75."""

    # Call dgx-router
    import subprocess
    result = subprocess.run(
        ['python3', '/Users/abserver/clawd/scripts/dgx-router.py', 'call', prompt, 'general', 'qwen'],
        capture_output=True, text=True, timeout=180
    )
    
    if result.returncode == 0:
        response = json.loads(result.stdout)
        scores_text = response.get('response', '')
        
        # Try to parse as JSON
        try:
            # Extract JSON array from response
            if '[' in scores_text and ']' in scores_text:
                start = scores_text.index('[')
                end = scores_text.rindex(']') + 1
                scores = json.loads(scores_text[start:end])
            else:
                scores = []
        except:
            scores = []
        
        # Output result
        output = {
            'timestamp': datetime.now().isoformat(),
            'model': 'qwen-72b-dgx',
            'projects_scanned': len(projects),
            'scores': scores,
            'raw_projects': projects
        }
        
        print(json.dumps(output, indent=2))
        sys.exit(0)
    else:
        print(json.dumps({'error': 'DGX router failed', 'stderr': result.stderr}), file=sys.stderr)
        sys.exit(1)
        
except Exception as e:
    print(json.dumps({'error': str(e)}), file=sys.stderr)
    sys.exit(1)
TASK

chmod +x /tmp/vic-deal-task-$$.py

# Run via DGX
echo "Fetching projects and scoring via DGX..." | tee -a "$LOG_FILE"

if ~/clawd/scripts/dgx-task-runner.sh --model qwen --task "python3 /tmp/vic-deal-task-$$.py"; then
    
    # Task output is JSON
    RESULT=$(cat /tmp/vic-deal-output-$$ 2>/dev/null || echo '{}')
    
    RESULTS_FILE="$OUTPUT_DIR/scan-${TIMESTAMP}.json"
    echo "$RESULT" > "$RESULTS_FILE"
    
    echo "✓ Scoring complete" | tee -a "$LOG_FILE"
    
    # Parse results
    SCORES=$(echo "$RESULT" | jq -r '.scores // []')
    PROJECT_COUNT=$(echo "$RESULT" | jq -r '.projects_scanned // 0')
    
    echo "" | tee -a "$LOG_FILE"
    echo "Projects scanned: $PROJECT_COUNT" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "=== Top Scores ===" | tee -a "$LOG_FILE"
    echo "$SCORES" | jq -r 'sort_by(-.score) | .[:5] | .[] | "[\(.score)] \(.name) - \(.reasoning)"' 2>/dev/null | tee -a "$LOG_FILE"
    
    # Alerts (>80)
    ALERTS=$(echo "$SCORES" | jq -r '[.[] | select(.score >= 80)] | length' 2>/dev/null || echo 0)
    if [[ $ALERTS -gt 0 ]]; then
        echo "" | tee -a "$LOG_FILE"
        echo "🔴 $ALERTS HIGH-SCORE ALERTS:" | tee -a "$LOG_FILE"
        echo "$SCORES" | jq -r '.[] | select(.score >= 80) | "  [\(.score)] \(.name) - \(.thesis)"' | tee -a "$LOG_FILE"
        
        # Auto-trigger deep analysis
        echo "" | tee -a "$LOG_FILE"
        echo "🔬 Triggering deep analysis..." | tee -a "$LOG_FILE"
        
        echo "$RESULT" | jq -r '.raw_projects[] as $p | .scores[] | select(.score >= 80 and .name == $p.name) | "\($p.name)|\($p.url)|\($p.owner)"' | \
        while IFS='|' read -r name url owner; do
            echo "  → $name ($owner)" | tee -a "$LOG_FILE"
            ~/clawd/scripts/project-deep-analysis.sh "$url" >> "$LOG_FILE" 2>&1 &
            ~/clawd/scripts/founder-deep-dive.sh "$owner" "$name" "$url" >> "$LOG_FILE" 2>&1 &
        done
        
        echo "  Analysis tasks running in background" | tee -a "$LOG_FILE"
    fi
    
    # Cleanup
    rm -f /tmp/vic-deal-task-$$.py
    
    echo "" | tee -a "$LOG_FILE"
    echo "✓ Results: $RESULTS_FILE" | tee -a "$LOG_FILE"
    
else
    echo "❌ Scoring failed" | tee -a "$LOG_FILE"
    rm -f /tmp/vic-deal-task-$$.py
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "=== Scan Complete ===" | tee -a "$LOG_FILE"
