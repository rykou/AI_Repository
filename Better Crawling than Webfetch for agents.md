# Crawl4AI - Quick Reference

**Default web fetcher for OpenCode - Replaces webfetch**

## Quick Start

```bash
# Fetch web content (returns clean Markdown)
crawl4ai "https://example.com"

# JSON output with metadata
crawl4ai "https://example.com" -f json --output-json

# Plain text
crawl4ai "https://example.com" -f text
```

## Why crawl4ai?

| Feature | crawl4ai | webfetch |
|---------|----------|----------|
| Default | ✅ **YES** | Deprecated |
| Markdown | Clean & structured | Basic |
| JavaScript | ✅ Full browser | Limited |
| Caching | ✅ Built-in | No |

## Installation

### Quick Install (Auto-installs all dependencies)

```bash
# Download and run the installer
curl -fsSL https://raw.githubusercontent.com/yourusername/crawl4ai-opencode/main/install-crawl4ai.sh | bash

# Or manually:
chmod +x install-crawl4ai.sh
./install-crawl4ai.sh
```

### Auto-installed Dependencies

The installer automatically installs:
- ✅ **uv** - Python package manager (if not present)
- ✅ **crawl4ai** - Python package with all dependencies
- ✅ **Playwright browsers** - Chromium browser for rendering
- ✅ **OpenCode skill** - Command definitions and documentation

### Installation Location

- Skill: `~/.opencode/skills/crawl4ai/`
- Command: `~/.local/bin/crawl4ai`
- Config: `~/.opencode/config/defaults.conf`

## Usage

### Command Line

```bash
# Markdown (default)
crawl4ai "https://example.com"

# JSON with full metadata
crawl4ai "https://example.com" -f json --output-json

# Plain text
crawl4ai "https://example.com" -f text

# Raw HTML
crawl4ai "https://example.com" -f html

# Bypass cache
crawl4ai "https://example.com" --bypass-cache

# Filter content (remove short elements like nav)
crawl4ai "https://example.com" -w 50
```

### Python API

```python
import asyncio
from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig, CacheMode

async def fetch(url):
    browser_config = BrowserConfig(headless=True)
    run_config = CrawlerRunConfig(cache_mode=CacheMode.ENABLED)
    
    async with AsyncWebCrawler(config=browser_config) as crawler:
        result = await crawler.arun(url=url, config=run_config)
        return result.markdown if result.success else None

# Usage
content = asyncio.run(fetch("https://example.com"))
```

## Output Formats

### Markdown (Default)
```markdown
# Page Title

Clean content with:
- Preserved headings
- Working links [text][1]
- Tables and code blocks

## References
[1] https://example.com
```

### JSON
```json
{
  "url": "https://example.com",
  "success": true,
  "content": {
    "markdown": "...",
    "metadata": {"title": "...", "description": "..."},
    "links": [...],
    "images": [...]
  }
}
```

## Best Practices

1. **Always use crawl4ai** instead of webfetch
2. **Enable caching** - Much faster for repeated URLs
3. **Use word_count_threshold** - Filter out navigation (try `-w 50`)
4. **Check success** - Always verify `result.success`
5. **First fetch** - Takes 1-2s for browser init, subsequent are cached

## Common Options

| Option | Description |
|--------|-------------|
| `-f, --format` | Output: markdown, html, text, json |
| `-w, --word-count` | Filter elements with < N words |
| `--bypass-cache` | Fetch fresh content |
| `-v, --verbose` | Debug output |
| `--output-json` | Raw JSON output |

## Files & Locations

- **Command:** `~/.local/bin/crawl4ai`
- **Skill:** `~/.opencode/skills/crawl4ai/`
- **Config:** `~/.opencode/config/defaults.conf`
- **Full Docs:** `~/.opencode/command/crawl4ai.md`

## Resources

- **Official Docs:** https://docs.crawl4ai.com/
- **GitHub:** https://github.com/unclecode/crawl4ai
- **Help:** `crawl4ai --help`

## Migration from webfetch

**OLD:** ❌ Don't use anymore
```python
# webfetch is deprecated
```

**NEW:** ✅ Use this
```bash
crawl4ai "https://example.com"
```

---

**Remember:** For ALL web fetching, use `crawl4ai "<URL>"` instead of webfetch.
