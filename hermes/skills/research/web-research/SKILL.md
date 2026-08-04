---
name: web-research
description: Investigate websites, check project status, and extract content from JS-rendered SPAs. Multi-layered fallback approach when direct scraping fails or returns empty templates.
category: research
---

# Web Research & Site Investigation

## When to use
- User asks about a project's status, roadmap, milestones, or recent activity
- Need to extract content from a website that renders client-side (SPA)
- Direct scraping returns empty or template-only HTML
- Need to confirm whether a project/company is still active

## Layered approach (try in order, stop when you have enough)

### Layer 1: Direct probing
```bash
# Check if the site is alive and get page title
curl -sL -A "Mozilla/5.0" "https://example.com" | head -5

# Check specific sub-pages
for page in /blog /roadmap /changelog /about /faq /updates /status /press /team; do
  echo "$page: $(curl -sL -o /dev/null -w '%{http_code}' "https://example.com$page")"
done
```

### Layer 2: RSS/Atom feeds
```bash
curl -sL "https://example.com/blog?format=rss"
curl -sL "https://example.com/blog?format=atom"
```

### Layer 3: Wayback Machine (essential for JS-rendered SPAs)
```bash
# Check if site is being archived and how recently
curl -sL "https://web.archive.org/web/timemap/link/example.com" | tail -5

# Get latest snapshot (replace * with date or keep * for latest)
curl -sL "https://web.archive.org/web/2026*/https://example.com/" | head -30
```

### Layer 4: Google cache
```bash
curl -sL "https://webcache.googleusercontent.com/search?q=cache:example.com&strip=1&vwsrc=0"
```

### Layer 5: API endpoints
- **Squarespace**: `https://example.com/.json` (generic), or embedded `SQUARESPACE_CONTEXT` in page source
- **GitHub**: `https://api.github.com/orgs/<org>/repos` or `https://api.github.com/repos/<owner>/<repo>/releases`
- **Reddit**: `https://old.reddit.com/r/<subreddit>/new.json` with `User-Agent: Mozilla/5.0`
- **X/Twitter**: `https://nitter.net/<handle>` (if nitter is up)

### Layer 6: Embedded JSON extraction (from HTML source)
```python
import re, json
# Squarespace sites embed data in Static.SQUARESPACE_CONTEXT
m = re.search(r'Static\.SQUARESPACE_CONTEXT\s*=\s*({.*?});', html, re.DOTALL)
if m:
    ctx = json.loads(m.group(1))
    # Check contentModifiedOn for last update timestamp
    ts = ctx.get('website', {}).get('contentModifiedOn', 0)
    # Check social accounts
    socials = ctx.get('website', {}).get('socialAccounts', [])
    # Check announcement bar
    ann = ctx.get('websiteSettings', {}).get('announcementBarSettings', {})
```

### Layer 7: Text extraction from HTML
```python
# Extract text from Squarespace data attributes
texts = re.findall(r'data-sqsp-text-block-content[^>]*>([^<]+)<', html)
# Or extract all visible text between tags
texts = re.findall(r'>([^<]{20,500})<', html)
# Or extract from JSON text fields
texts = re.findall(r'"text":"([^"]{20,500})"', html)
```

## Key signals a project is alive
- **Website**: online, regularly updated (`contentModifiedOn` timestamp changes weekly/monthly)
- **Wayback Machine**: shows regular snapshots (weekly/monthly cadence = active development)
- **Social media**: posts within the last month on Reddit, X/Twitter, Discord
- **Blog/Changelog**: recent entries or regular posting cadence
- **Pricing/Store**: current pricing pages, active Early Access program
- **Copyright footer**: shows current year or recent year
- **GitHub**: recent commits, releases, or issue activity

## Pitfalls
- **Squarespace SPAs**: Content is loaded client-side via JavaScript. The HTML source contains only template/skeleton code. Cannot scrape content without a headless browser (Puppeteer/Playwright). The Wayback Machine captures the same empty template.
- **Reddit API**: Blocks requests without proper User-Agent. Use `old.reddit.com` with `User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0`.
- **GitHub API**: Rate-limited to 60 unauthenticated requests/hour. Use a token via `Authorization: Bearer <token>` header for higher limits.
- **Wayback Machine**: Only captures what the crawler saw at crawl time. JS-rendered content may be empty in archived versions too.
- **404 is not always final**: Try common alternative paths. A missing `/roadmap` doesn't mean there's no roadmap — it might be at `/about#roadmap` or behind a login.
- **HTTPS certificate issues**: Some sites use self-signed certs. Add `-k` to curl (but trust the result less).
- **Redirects**: Some pages redirect to a main SPA shell. Check `-w '%{redirect_url}'` in curl.