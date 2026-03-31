---
name: deal-sourcing
description: Predictive deal sourcing for AI-native venture capital. Scan GitHub Trending, HackerNews Show HN, and other sources to find early-stage projects BEFORE they launch on Product Hunt. Score projects by signals, generate alerts, save to Obsidian pipeline.
when_to_use: Use when scanning for investment opportunities, monitoring builder activity, finding pre-seed projects, or tracking trending repos.
---

# Deal Sourcing Skill

Automated early-stage deal discovery for AI-native VC.

## Quick Start

```bash
# Daily scan (all sources)
${SKILL_DIR}/scripts/daily-scan.sh

# Individual sources
${SKILL_DIR}/scripts/github-trending.sh
${SKILL_DIR}/scripts/hackernews-showhn.sh

# Score a specific project
${SKILL_DIR}/scripts/score-project.sh <github-url>
```

## Configuration

Copy `config.example.json` to `config.json` and fill in your values:

```json
{
  "obsidian_path": "${OBSIDIAN_VAULT}/Projects/VC/Pipeline/Early-Stage",
  "min_score": 50,
  "notify_threshold": 70,
  "telegram_chat_id": "${TELEGRAM_CHAT_ID}",
  "sources": ["github", "hackernews", "indiehackers"]
}
```

## Sources & Signals

### GitHub Trending
- **URL:** https://github.com/trending
- **Signals:** Stars velocity, contributor quality, description keywords
- **Filter:** AI/ML, developer tools, infrastructure

### HackerNews Show HN
- **URL:** https://news.ycombinator.com/show
- **Signals:** Points velocity, comment quality, founder engagement
- **Filter:** Building in public, solo founders, early stage

### Scoring Model

| Signal | Weight | Description |
|--------|--------|-------------|
| `stars_velocity` | 20 | Stars/day vs category average |
| `founder_track` | 25 | Previous successful projects |
| `ai_relevance` | 20 | AI/agent/LLM keywords |
| `building_public` | 15 | Active Twitter/blog presence |
| `early_stage` | 20 | No funding, <3 months old |

**Thresholds:**
- Score ≥ 70: 🔴 Alert immediately
- Score 50-69: 🟡 Add to watchlist
- Score < 50: Skip

## Output

### Obsidian Integration
Saves to the path configured in `config.json`.

Format:
```markdown
---
source: github-trending
score: 75
date_found: YYYY-MM-DD
status: new
---

# {Project Name}

**URL:** {url}
**Founder:** {name} (@handle)
**Score:** {score}/100

## Signals
- Stars: X (velocity: +Y/day)
- Founder: {track record}
- Stage: {pre-seed/seed}

## Why Interesting
{auto-generated reasoning}

## Next Steps
- [ ] Research founder background
- [ ] Check for funding announcements
- [ ] Draft outreach message
```

### JSON Output
For automation, use `--json` flag:
```bash
${SKILL_DIR}/scripts/daily-scan.sh --json > /tmp/deals.json
```

## Cron Setup

Daily scan at 09:00:
```bash
# Add to cron
${SKILL_DIR}/scripts/daily-scan.sh --notify
```

## Outreach Templates

See `references/outreach-templates.md` for message templates.
