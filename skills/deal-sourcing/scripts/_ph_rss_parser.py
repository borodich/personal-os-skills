#!/usr/bin/env python3
"""
Product Hunt RSS parser with AINative scoring.
Reads RSS XML from stdin, outputs JSON array to stdout.
Usage: echo "$RSS" | python3 _ph_rss_parser.py <cache_file>
"""
import sys, os, xml.etree.ElementTree as ET, json, re, hashlib

CACHE_FILE = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser('~/.cache/deal-sourcing/ph-seen.txt')
rss_content = sys.stdin.read()

# AINative scoring keywords
AI_KEYWORDS = ['ai', 'agent', 'llm', 'gpt', 'copilot', 'automat', 'ml', 'neural',
               'chatbot', 'whisper', 'embedding', 'rag', 'openai', 'claude',
               'artificial intelligence', 'machine learning', 'generative']
BUILDER_KW  = ['open source', 'open-source', 'developer', 'api', 'sdk', 'cli',
               'saas', 'tool', 'productivity', 'workflow', 'autonomous', 'platform']
B2B_KW      = ['b2b', 'enterprise', 'team', 'startup', 'business', 'analytics',
               'crm', 'sales', 'marketing', 'ops']
AGENT_KW    = ['autonomous', 'agentic', 'agent-first', 'no-code', 'no code',
               'multi-agent', 'self-operating', 'ai-powered', 'ai native']
SKIP_KW     = ['dating', 'adult', 'casino', 'gambling', 'meme coin']

os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
seen = set()
if os.path.exists(CACHE_FILE):
    with open(CACHE_FILE) as f:
        seen = set(f.read().splitlines())

def score_entry(title, desc):
    text = (title + ' ' + desc).lower()
    score = 30
    reasons = []

    for kw in SKIP_KW:
        if kw in text:
            return 0, ['skip:' + kw]

    ai_hits = sum(1 for kw in AI_KEYWORDS if kw in text)
    if ai_hits >= 3:
        score += 30; reasons.append(f'ai_strong({ai_hits})')
    elif ai_hits >= 1:
        score += 15; reasons.append(f'ai_weak({ai_hits})')

    b_hits = sum(1 for kw in BUILDER_KW if kw in text)
    if b_hits >= 2:
        score += 15; reasons.append(f'builder({b_hits})')
    elif b_hits >= 1:
        score += 7

    bb_hits = sum(1 for kw in B2B_KW if kw in text)
    if bb_hits >= 2:
        score += 10; reasons.append(f'b2b({bb_hits})')

    agent_hits = sum(1 for kw in AGENT_KW if kw in text)
    if agent_hits >= 1:
        score += 15; reasons.append(f'agent_first({agent_hits})')

    return min(score, 100), reasons

def strip_html(text):
    return re.sub(r'<[^>]+>', '', text or '').strip()

try:
    root = ET.fromstring(rss_content)
    ns = root.tag.split('}')[0] + '}' if root.tag.startswith('{') else ''
    # ET's find with namespace prefix
    items = root.findall(f'{ns}entry') or root.findall(f'.//{ns}entry') or root.findall('.//item')

    results = []
    new_seen = []

    for item in items[:30]:
        title_el = item.find(f'{ns}title') if item.find(f'{ns}title') is not None else item.find('title')
        link_el  = item.find(f'{ns}link')  if item.find(f'{ns}link')  is not None else item.find('link')
        desc_el  = (item.find(f'{ns}summary') if item.find(f'{ns}summary') is not None
                    else item.find(f'{ns}content') if item.find(f'{ns}content') is not None
                    else item.find('description'))

        title = (title_el.text or '').strip() if title_el is not None else ''
        link  = (link_el.get('href') or (link_el.text or '').strip()
                 if link_el is not None else '')
        desc  = strip_html((desc_el.text or '') if desc_el is not None else '')[:500]

        if not title or not link:
            continue

        url_hash = hashlib.md5(link.encode()).hexdigest()[:12]
        if url_hash in seen:
            continue

        score, reasons = score_entry(title, desc)
        if score < 40:
            continue

        new_seen.append(url_hash)
        results.append({
            'source': 'product_hunt_rss',
            'title': title,
            'url': link,
            'description': desc[:300],
            'score': score,
            'reasons': reasons,
        })

    results.sort(key=lambda x: x['score'], reverse=True)

    with open(CACHE_FILE, 'a') as f:
        for h in new_seen:
            f.write(h + '\n')

    print(json.dumps(results, ensure_ascii=False, indent=2))

except Exception as e:
    sys.stderr.write(f'[ph-rss] parse error: {e}\n')
    print('[]')
