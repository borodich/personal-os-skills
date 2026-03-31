#!/bin/bash
# Vic Deal Sourcing - DGX Qwen 72B version
# Runs at 6:00 AM daily via cron

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$HOME/clawd/workspaces/vc/deal-sourcing"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_FILE="$OUTPUT_DIR/scan-${TIMESTAMP}.json"
LOG_FILE="$HOME/clawd/logs/deal-sourcing.log"

mkdir -p "$OUTPUT_DIR"

echo "=== Vic Deal Sourcing - DGX Qwen 72B ===" | tee -a "$LOG_FILE"
echo "Time: $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Fetch GitHub Trending (last 7 days, >50 stars)
echo "Fetching GitHub Trending..." | tee -a "$LOG_FILE"
WEEK_AGO=$(date -u -v-7d +%Y-%m-%d 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%d)
PROJECTS=$(curl -s "https://api.github.com/search/repositories?q=created:>$WEEK_AGO+stars:>50&sort=stars&order=desc&per_page=15" | \
    jq -c '.items | map({
        name: .name,
        url: .html_url,
        stars: .stargazers_count,
        description: .description,
        language: .language,
        owner: .owner.login,
        created: .created_at
    })')

if [[ -z "$PROJECTS" ]] || [[ "$PROJECTS" == "null" ]]; then
    echo "❌ Failed to fetch projects" | tee -a "$LOG_FILE"
    exit 1
fi

PROJECT_COUNT=$(echo "$PROJECTS" | jq 'length')
echo "✓ Fetched $PROJECT_COUNT projects" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Create scoring task
cat > /tmp/vic-deal-task-$$.sh << TASK_SCRIPT
#!/bin/bash
# Task runs with Qwen 72B available on port 8081

PROJECTS='$PROJECTS'

PROMPT="You are a CONSERVATIVE VC analyst specialized in early-stage tech investments.

Score these GitHub Trending projects for INVESTMENT POTENTIAL (0-100).

HARSH CALIBRATION:
- 90-100: Exceptional (top 1% - would invest \\\$1M+ today)
- 80-89: Strong (clear PMF, proven team, good traction)
- 70-79: Promising (interesting but needs validation)
- 60-69: Watchlist (monitor for growth signals)
- 50-59: Pass (not ready for investment)
- <50: Reject

Projects:
\$PROJECTS

For EACH project output:
{\"name\": \"ProjectName\", \"score\": 75, \"reasoning\": \"Brief reason (1-2 sentences)\", \"thesis\": \"Investment angle or pass reason\"}

Output valid JSON array. Be HARSH - most projects should be 50-75."

# Call DGX Qwen via router
cd ~/clawd
python3 scripts/dgx-router.py call "\$PROMPT" general qwen > /tmp/vic-response-$$.json

# Parse response
jq -r '.response' /tmp/vic-response-$$.json > /tmp/vic-scores-$$.txt
TASK_SCRIPT

chmod +x /tmp/vic-deal-task-$$.sh

# Run via DGX task runner
echo "Scoring via DGX Qwen 72B..." | tee -a "$LOG_FILE"

if ~/clawd/scripts/dgx-task-runner.sh \
    --model qwen \
    --task "/tmp/vic-deal-task-$$.sh" \
    --timeout 120; then
    
    echo "✓ Scoring complete" | tee -a "$LOG_FILE"
    
    # Extract scores
    SCORES=$(cat /tmp/vic-scores-$$.txt)
    
    # Create result JSON
    cat > "$RESULTS_FILE" << RESULT
{
  "timestamp": "$TIMESTAMP",
  "date": "$(date -Iseconds)",
  "model": "qwen-72b-dgx",
  "projects_scanned": $PROJECT_COUNT,
  "scores": $SCORES,
  "raw_projects": $PROJECTS
}
RESULT
    
    echo "" | tee -a "$LOG_FILE"
    echo "=== Top Scores ===" | tee -a "$LOG_FILE"
    echo "$SCORES" | jq -r 'sort_by(-.score) | .[:5] | .[] | "[\(.score)] \(.name) - \(.reasoning)"' | tee -a "$LOG_FILE"
    
    # Alerts (>80) + Auto deep dive
    ALERTS=$(echo "$SCORES" | jq -r '[.[] | select(.score >= 80)] | length')
    if [[ $ALERTS -gt 0 ]]; then
        echo "" | tee -a "$LOG_FILE"
        echo "🔴 $ALERTS HIGH-SCORE ALERTS:" | tee -a "$LOG_FILE"
        echo "$SCORES" | jq -r '.[] | select(.score >= 80) | "  [\(.score)] \(.name) - \(.thesis)"' | tee -a "$LOG_FILE"
        
        # Auto-trigger deep analysis for >80 scores
        echo "" | tee -a "$LOG_FILE"
        echo "🔬 Triggering deep analysis for high-score projects..." | tee -a "$LOG_FILE"
        
        echo "$SCORES" | jq -r '.[] | select(.score >= 80) | "\(.name)|\(.url)"' | while IFS='|' read -r name url; do
            echo "  Analyzing: $name" | tee -a "$LOG_FILE"
            
            # Project analysis
            ~/clawd/scripts/project-deep-analysis.sh "$url" >> "$LOG_FILE" 2>&1 &
            
            # Founder analysis (extract owner from URL)
            OWNER=$(echo "$url" | sed -E 's|https://github.com/([^/]+)/.*|\1|')
            ~/clawd/scripts/founder-deep-dive.sh "$OWNER" "$name" "$url" >> "$LOG_FILE" 2>&1 &
        done
        
        echo "  Deep analysis tasks spawned (running in background)" | tee -a "$LOG_FILE"
    fi
    
    # Cleanup
    rm -f /tmp/vic-deal-task-$$.sh /tmp/vic-response-$$.json /tmp/vic-scores-$$.txt
    
    echo "" | tee -a "$LOG_FILE"
    echo "✓ Results saved: $RESULTS_FILE" | tee -a "$LOG_FILE"
    
else
    echo "❌ Scoring failed" | tee -a "$LOG_FILE"
    rm -f /tmp/vic-deal-task-$$.sh /tmp/vic-response-$$.json /tmp/vic-scores-$$.txt
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "=== Scan Complete ===" | tee -a "$LOG_FILE"
