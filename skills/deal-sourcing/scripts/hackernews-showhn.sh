#!/bin/bash

# Fetch Show HN stories from HackerNews API and output as JSON array with details

python3 -W ignore -E -c '
import urllib.request
import json
import os

os.environ["PYTHONIOENCODING"] = "utf-8"

stories = []

try:
    with urllib.request.urlopen("https://hacker-news.firebaseio.com/v0/showstories.json", timeout=10) as resp:
        story_ids = json.load(resp)[:25]
except Exception:
    story_ids = []

for sid in story_ids:
    try:
        url = f"https://hacker-news.firebaseio.com/v0/item/{sid}.json"
        with urllib.request.urlopen(url, timeout=8) as resp:
            item = json.load(resp)
        if not item:
            continue
        stories.append({
            "id": item.get("id"),
            "title": item.get("title", ""),
            "url": item.get("url", f"https://news.ycombinator.com/item?id={sid}"),
            "score": item.get("score", 0),
            "by": item.get("by", ""),
            "time": item.get("time", 0),
            "descendants": item.get("descendants", 0),
            "text": (item.get("text") or "")[:300],
        })
    except Exception:
        continue

print(json.dumps(stories))
'
