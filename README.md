# Personal OS Skills

> *An AI agent that doesn't learn is just an expensive chatbot.*

A collection of skills for building an AI agent that grows with you — accumulating memory, gaining capabilities, and becoming irreplaceable over time.

This is the **Evolutionary Model**: your agent doesn't reset. It remembers. It compounds.

---

## What Is This?

Personal OS Skills is an open-source library of skills for AI agent runtimes (OpenClaw, Claude Code, and compatible systems).

Unlike a set of tools you run once, these skills are designed around a core idea: **the value of your agent grows non-linearly with time**. Not because the model gets smarter — but because the accumulated context, memory, and protocols become a moat.

```
Month 1:  agent knows your name and timezone
Month 2:  agent knows your projects, contacts, communication style
Month 3:  agent anticipates needs, catches mistakes, runs proactive checks
Month 6:  agent has skills specific to your workflow
Month 12: agent carries institutional knowledge no new model can replicate
```

The intelligence isn't in the model. It's in the files. And you own them.

---

## The Evolutionary Model

Three axes of growth:

**Memory** — agent persists context across sessions via structured files  
**Skills** — agent gains new capabilities as you install or create skills  
**Protocols** — agent behavior becomes more reliable as rules are documented

```
SOUL.md       → who the agent is
USER.md       → who it serves
memory/       → what it has learned
skills/       → what it can do
AGENTS.md     → how it behaves reliably
```

Every session, the agent reads these files. Every session, it gets a little better.

---

## Skills

| Skill | Category | What it does |
|-------|----------|-------------|
| [`onboarding`](skills/onboarding/) | 🚀 Setup | Set up your Personal OS in 15 min via conversational interview. Creates all 5 foundation files. |
| [`recall`](skills/recall/) | 🧠 Memory | Load context from past sessions. Temporal, topic, and graph modes. Ends with One Thing. |
| [`evolutionary-model`](skills/evolutionary-model/) | 🧬 Meta | The framework itself. Read this to understand the architecture. |
| [`meeting-prep`](skills/meeting-prep/) | 📅 Productivity | Research contacts before meetings. Creates briefing cards. |
| [`deal-sourcing`](skills/deal-sourcing/) | 🔍 Research | Scan GitHub Trending + HackerNews for early-stage projects. Score by signals. |
| [`jtbd-analyst`](skills/jtbd-analyst/) | 🎯 Analysis | Advanced JTBD analysis (Zamesin methodology). Find core jobs, segment markets, find growth points. |
| [`superflow`](skills/superflow/) | ⚡ Development | Full dev workflow: discovery → autonomous execution → PR per sprint. Multi-agent. |
| [`bug-fix-protocol`](skills/bug-fix-protocol/) | 🐛 Development | Every bug fix = two fixes: code + test system. Never repeat the same bug. |
| [`claude-code-task`](skills/claude-code-task/) | ⚙️ Automation | Run Claude Code tasks async in background. Zero tokens while it works. |
| [`content-creator`](skills/content-creator/) | ✍️ Content | Generate posts in your voice. Configure style, tone, and topics. |
| [`voice-telegram`](skills/voice-telegram/) | 🎙️ Communication | Transcribe Telegram voice messages via local Whisper. Privacy-first. |
| [`moltbook`](skills/moltbook/) | 🦞 Social | Post, comment, and participate in Moltbook — the social network for AI agents. |

**Coming soon:** `daily-log`, `weekly-review`, `habit-tracker`, `email-triage`

---

## Quick Start

**Option 1 — Start fresh (recommended):**
```bash
# Clone the repo
git clone https://github.com/borodich/personal-os-skills.git
cd personal-os-skills

# Copy foundation templates
cp templates/* ~/your-agent-workspace/

# Copy the skills you want
cp -r skills/onboarding ~/.claude/skills/
cp -r skills/recall ~/.claude/skills/

# In your agent, run:
# /onboarding
```

**Option 2 — Single skill via curl:**
```bash
mkdir -p ~/.claude/skills/recall
curl -o ~/.claude/skills/recall/SKILL.md \
  https://raw.githubusercontent.com/borodich/personal-os-skills/main/skills/recall/SKILL.md
```

**Option 3 — Claude Code plugin marketplace:**
```
/plugin marketplace add borodich/personal-os-skills
```

---

## Foundation Templates

The `templates/` directory contains starter files for your agent workspace:

| File | Purpose |
|------|---------|
| `SOUL.md` | Agent personality — the most important file. Defines tone, values, operating principles. |
| `USER.md` | Your profile — name, timezone, preferences. Agent reads this every session. |
| `IDENTITY.md` | Agent's name, role, emoji. |
| `AGENTS.md` | Operating rules — memory protocol, safety rules, what to do without asking. |
| `MEMORY.md` | Long-term memory starter. Grows over time. |
| `HEARTBEAT.md` | Proactive check-in schedule. Agent stays useful between conversations. |

→ Start with `/onboarding` skill to auto-generate these through a conversation. Or fill them in manually using the templates.

---

## Why Not Just ChatGPT?

| | ChatGPT / Standard AI | Personal OS Skills |
|---|---|---|
| Memory | Resets every session | Persists across sessions via files |
| Skills | Fixed capabilities | Grows as you add skills |
| Context | Generic | Specific to you |
| Mistakes | Repeated | Documented + prevented via protocols |
| Value over time | Flat | Compounding |
| Provider lock-in | Locked | Files you own, works with any runtime |
| Active when? | When you're in the chat | 24/7 via cron + heartbeat |

The key difference: **the agent works when you're not around**. Checks your inbox, preps for tomorrow's meetings, monitors what you care about — all without you opening a chat window.

---

## Compatibility

| Runtime | Status | Notes |
|---------|--------|-------|
| [OpenClaw](https://openclaw.ai) | ✅ Full support | Cron, heartbeat, multi-agent, Telegram |
| [Claude Code](https://claude.ai/claude-code) | ✅ Full support | `/plugin marketplace` install |
| Claude.ai | ⚠️ Partial | Skills work, no cron/heartbeat |
| Any agent with file access | ✅ Core skills | Memory + recall work universally |

---

## Skill Progression

Recommended order for getting started:

```
1. /onboarding          → create your foundation (start here)
2. /recall              → load context from past sessions
3. /meeting-prep        → prep for your first meeting
4. /jtbd-analyst        → analyze what you're building
5. /superflow           → build something with the full dev workflow
```

---

## Architecture

Each skill follows the same structure:

```
skills/
  skill-name/
    SKILL.md            ← instructions + frontmatter (name, description, when_to_use)
    README.md           ← human-readable docs
    scripts/            ← executable helpers (bash, python)
    config.example.json ← configurable parameters
```

**`when_to_use` is the key field.** Without it, the agent doesn't know when to auto-activate the skill. Every skill in this library has it.

---

## Contributing

Skills are just markdown files. To contribute:

1. Fork this repo
2. Create `skills/your-skill/SKILL.md`
3. Required frontmatter: `name`, `description`, `when_to_use`
4. Remove all personal context (no hardcoded names, paths, tokens)
5. Add `config.example.json` for any user-specific settings
6. Write a `README.md`
7. Open a PR

**Good first contributions:** `daily-log`, `weekly-review`, `email-triage`, `habit-tracker`, platform-specific integrations.

---

## Inspired By

- [ArtemXTech/personal-os-skills](https://github.com/ArtemXTech/personal-os-skills) — excellent Obsidian + Claude Code integration, especially `recall`
- [BayramAnnakov/ai-personal-os-skills](https://github.com/BayramAnnakov/ai-personal-os-skills) — strong onboarding flow and skill progression concept
- [OpenClaw](https://openclaw.ai) — the runtime that makes 24/7 agents possible

---

## License

MIT — do whatever you want with it.

---

*Built by people who got tired of explaining themselves to their AI every single session.*
