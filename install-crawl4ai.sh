#!/bin/bash
# =============================================================================
# Crawl4AI Installer for OpenCode
# =============================================================================
# This script installs Crawl4AI as the DEFAULT web fetcher for OpenCode.
# It safely appends to existing configurations without overwriting them.
#
# Requirements:
#   - OpenCode must be installed
#   - uv will be auto-installed if not available
#
# Auto-installed Dependencies:
#   - uv (Python package manager)
#   - crawl4ai Python package
#   - Playwright browsers (Chromium)
#
# Usage:
#   chmod +x install-crawl4ai.sh
#   ./install-crawl4ai.sh
#
# The script is idempotent - safe to run multiple times.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SKILL_NAME="crawl4ai"
SKILL_DIR="$HOME/.opencode/skills/$SKILL_NAME"
COMMAND_DIR="$HOME/.opencode/command"
CONFIG_DIR="$HOME/.opencode/config"
BIN_DIR="$HOME/.local/bin"

# Script variables
DRY_RUN=false
VERBOSE=false

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if opencode directory exists
    if [ ! -d "$HOME/.opencode" ]; then
        log_error "OpenCode is not installed. Please install OpenCode first."
        exit 1
    fi
    
    # Check for uv and auto-install if missing
    if ! command_exists uv; then
        log_warn "uv is not installed. Auto-installing uv..."
        if [ "$DRY_RUN" = true ]; then
            log_verbose "Would auto-install uv using: curl -LsSf https://astral.sh/uv/install.sh | sh"
        else
            curl -LsSf https://astral.sh/uv/install.sh | sh
            # Source the new uv installation
            export PATH="$HOME/.cargo/bin:$PATH"
            if ! command_exists uv; then
                log_error "Failed to install uv. Please install manually:"
                log_error "  curl -LsSf https://astral.sh/uv/install.sh | sh"
                exit 1
            fi
            log_success "uv installed successfully"
        fi
    fi
    
    log_success "Prerequisites met"
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."
    
    if [ "$DRY_RUN" = true ]; then
        log_verbose "Would create directories:"
        log_verbose "  - $SKILL_DIR/references"
        log_verbose "  - $COMMAND_DIR"
        log_verbose "  - $CONFIG_DIR"
        log_verbose "  - $BIN_DIR"
        log_success "Directories (dry-run)"
        return 0
    fi
    
    mkdir -p "$SKILL_DIR/references"
    mkdir -p "$COMMAND_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$BIN_DIR"
    
    log_success "Directories created"
}

# Install crawl4ai package
install_crawl4ai_package() {
    log_info "Installing crawl4ai package..."
    
    cd "$SKILL_DIR/references"
    
    # Check if already installed
    if [ -d ".venv" ] && [ -f ".venv/bin/python" ]; then
        log_warn "Virtual environment already exists. Checking crawl4ai..."
        if uv pip show crawl4ai >/dev/null 2>&1; then
            log_success "crawl4ai is already installed"
            return 0
        fi
    fi
    
    # Create virtual environment if it doesn't exist
    if [ ! -d ".venv" ]; then
        log_verbose "Creating virtual environment..."
        uv venv
    fi
    
    # Install crawl4ai
    if [ "$DRY_RUN" = true ]; then
        log_verbose "Would install crawl4ai package (dry-run)"
        log_verbose "Would install Playwright browsers (dry-run)"
        log_success "crawl4ai package (dry-run)"
        return 0
    fi
    
    log_verbose "Installing crawl4ai package..."
    uv pip install crawl4ai
    
    # Install playwright browsers
    log_verbose "Installing Playwright browsers..."
    uv run python -m playwright install chromium
    
    log_success "crawl4ai package installed"
}

# Create Python fetch script
create_fetch_script() {
    log_info "Creating fetch script..."
    
    local fetch_script="$SKILL_DIR/references/crawl4ai_fetch.py"
    
    if [ -f "$fetch_script" ]; then
        log_warn "Fetch script already exists. Skipping..."
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_verbose "Would create fetch script at: $fetch_script (dry-run)"
        log_success "Fetch script (dry-run)"
        return 0
    fi
    
    cat > "$fetch_script" << 'FETCH_SCRIPT_EOF'
#!/usr/bin/env python3
"""
Crawl4AI Web Fetcher - A wrapper for crawl4ai to fetch web content.
Replaces the default webfetch tool with LLM-friendly web crawling capabilities.
"""

import asyncio
import argparse
import json
import sys
from typing import Optional

from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig, CacheMode


async def fetch_url(
    url: str,
    output_format: str = "markdown",
    word_count_threshold: int = 1,
    bypass_cache: bool = False,
    verbose: bool = False
) -> dict:
    """
    Fetch content from a URL using Crawl4AI.
    
    Args:
        url: The URL to fetch
        output_format: Output format - 'markdown', 'html', 'text', 'json'
        word_count_threshold: Minimum word count threshold for content filtering
        bypass_cache: Whether to bypass cache
        verbose: Enable verbose output
    
    Returns:
        Dictionary containing the fetched content and metadata
    """
    browser_config = BrowserConfig(
        headless=True,
        verbose=verbose,
    )
    
    cache_mode = CacheMode.BYPASS if bypass_cache else CacheMode.ENABLED
    
    run_config = CrawlerRunConfig(
        word_count_threshold=word_count_threshold,
        cache_mode=cache_mode,
    )
    
    async with AsyncWebCrawler(config=browser_config) as crawler:
        result = await crawler.arun(url=url, config=run_config)
        
        output = {
            "url": url,
            "success": result.success,
        }
        
        if result.success:
            # Format output based on requested format
            if output_format == "html":
                output["content"] = result.html
                output["format"] = "html"
            elif output_format == "text":
                # Strip HTML tags for plain text
                from bs4 import BeautifulSoup
                soup = BeautifulSoup(result.html, 'html.parser')
                output["content"] = soup.get_text(separator='\n', strip=True)
                output["format"] = "text"
            elif output_format == "json":
                # Return structured data
                output["content"] = {
                    "markdown": result.markdown,
                    "html": result.html,
                    "metadata": {
                        "title": result.metadata.get("title", ""),
                        "description": result.metadata.get("description", ""),
                        "author": result.metadata.get("author", ""),
                        "keywords": result.metadata.get("keywords", ""),
                    },
                    "links": result.links if hasattr(result, 'links') else [],
                    "images": result.media.get("images", []) if hasattr(result, 'media') else [],
                }
                output["format"] = "json"
            else:  # default to markdown
                output["content"] = result.markdown
                output["format"] = "markdown"
                
            # Add metadata
            output["metadata"] = {
                "title": result.metadata.get("title", ""),
                "description": result.metadata.get("description", ""),
                "author": result.metadata.get("author", ""),
                "keywords": result.metadata.get("keywords", ""),
            }
        else:
            output["error"] = result.error_message if hasattr(result, 'error_message') else "Unknown error"
        
        return output


def main():
    parser = argparse.ArgumentParser(
        description="Fetch web content using Crawl4AI - LLM-friendly web crawler"
    )
    parser.add_argument(
        "url",
        help="URL to fetch"
    )
    parser.add_argument(
        "-f", "--format",
        choices=["markdown", "html", "text", "json"],
        default="markdown",
        help="Output format (default: markdown)"
    )
    parser.add_argument(
        "-w", "--word-count",
        type=int,
        default=1,
        help="Minimum word count threshold for content filtering"
    )
    parser.add_argument(
        "--bypass-cache",
        action="store_true",
        help="Bypass cache and fetch fresh content"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    parser.add_argument(
        "--output-json",
        action="store_true",
        help="Output raw JSON instead of formatted content"
    )
    
    args = parser.parse_args()
    
    try:
        result = asyncio.run(fetch_url(
            url=args.url,
            output_format=args.format,
            word_count_threshold=args.word_count,
            bypass_cache=args.bypass_cache,
            verbose=args.verbose
        ))
        
        if args.output_json or args.format == "json":
            print(json.dumps(result, indent=2))
        else:
            if result.get("success"):
                print(result["content"])
            else:
                print(f"Error: {result.get('error', 'Unknown error')}", file=sys.stderr)
                sys.exit(1)
                
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
FETCH_SCRIPT_EOF

    chmod +x "$fetch_script"
    log_success "Fetch script created"
}

# Create CLI wrapper
create_cli_wrapper() {
    log_info "Creating CLI wrapper..."
    
    local wrapper_script="$SKILL_DIR/references/crawl4ai"
    
    if [ -f "$wrapper_script" ]; then
        log_warn "CLI wrapper already exists. Skipping..."
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_verbose "Would create CLI wrapper at: $wrapper_script (dry-run)"
        log_success "CLI wrapper (dry-run)"
        return 0
    fi
    
    cat > "$wrapper_script" << 'WRAPPER_EOF'
#!/bin/bash
# =============================================================================
# Crawl4AI - DEFAULT Web Fetcher for OpenCode
# =============================================================================
# This is the DEFAULT tool for all web fetching operations in opencode.
# It replaces webfetch entirely.
#
# Usage: crawl4ai <URL> [options]
# =============================================================================

set -e

SKILL_DIR="$HOME/.opencode/skills/crawl4ai/references"
FETCH_SCRIPT="$SKILL_DIR/crawl4ai_fetch.py"

# Show help
show_help() {
    cat << EOF
Crawl4AI - DEFAULT Web Fetcher for OpenCode

USAGE:
    crawl4ai <URL> [options]

DESCRIPTION:
    This is the DEFAULT tool for fetching web content in opencode.
    It replaces webfetch and provides superior Markdown output,
    JavaScript rendering, and content extraction.

OPTIONS:
    -f, --format {markdown,html,text,json}  Output format (default: markdown)
    -w, --word-count INTEGER                Minimum word count threshold
    --bypass-cache                          Bypass cache for fresh content
    -v, --verbose                           Enable verbose output
    --output-json                           Output raw JSON
    -h, --help                              Show this help message

EXAMPLES:
    # Fetch as markdown (default)
    crawl4ai "https://example.com"

    # Fetch as JSON with metadata
    crawl4ai "https://example.com" -f json --output-json

    # Fetch as plain text
    crawl4ai "https://example.com" -f text

    # Fetch fresh content (bypass cache)
    crawl4ai "https://example.com" --bypass-cache

NOTES:
    - This tool REPLACES webfetch - always use crawl4ai instead
    - First fetch may take 1-2s as browser initializes
    - Subsequent fetches are cached and much faster
    - Supports JavaScript-rendered content

SEE ALSO:
    - Documentation: https://docs.crawl4ai.com/
    - GitHub: https://github.com/unclecode/crawl4ai
    - Skill: ~/.opencode/skills/crawl4ai/

EOF
}

# Check if URL is provided
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if the fetch script exists
if [ ! -f "$FETCH_SCRIPT" ]; then
    echo "Error: Crawl4AI fetch script not found at $FETCH_SCRIPT" >&2
    echo "Please ensure crawl4ai is installed correctly." >&2
    exit 1
fi

# Run the Python script with all arguments
cd "$SKILL_DIR" && uv run python crawl4ai_fetch.py "$@"
WRAPPER_EOF

    chmod +x "$wrapper_script"
    log_success "CLI wrapper created"
}

# Create symlink in ~/.local/bin
create_symlink() {
    log_info "Creating symlink in ~/.local/bin..."
    
    local wrapper="$SKILL_DIR/references/crawl4ai"
    local symlink="$BIN_DIR/crawl4ai"
    
    if [ "$DRY_RUN" = true ]; then
        if [ -L "$symlink" ]; then
            log_verbose "Would update existing symlink (dry-run)"
        elif [ -f "$symlink" ]; then
            log_verbose "Would backup existing file and create symlink (dry-run)"
        else
            log_verbose "Would create symlink: $symlink -> $wrapper (dry-run)"
        fi
        log_success "Symlink (dry-run)"
        return 0
    fi
    
    if [ -L "$symlink" ]; then
        log_warn "Symlink already exists. Updating..."
        rm "$symlink"
    elif [ -f "$symlink" ]; then
        log_warn "File exists at $symlink. Backing up..."
        mv "$symlink" "$symlink.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    ln -s "$wrapper" "$symlink"
    log_success "Symlink created: $symlink -> $wrapper"
}

# Create or append to SKILL.md
create_skill_doc() {
    log_info "Creating/updating SKILL.md..."
    
    local skill_file="$SKILL_DIR/SKILL.md"
    local temp_file=$(mktemp)
    
    # Create the skill content
    cat > "$temp_file" << 'SKILL_EOF'
---
name: crawl4ai
description: DEFAULT web fetching tool for all opencode commands. ALWAYS use this instead of webfetch for fetching web content. Provides LLM-friendly Markdown output, JavaScript rendering, and superior content extraction.
license: MIT
compatibility: Requires crawl4ai Python package. Replaces webfetch entirely.
metadata:
  author: OpenCode
  version: "1.1"
  replaces: webfetch
---

# Crawl4AI - DEFAULT Web Fetcher

**⚠️ IMPORTANT: This skill REPLACES webfetch. Always use crawl4ai for all web fetching operations.**

Crawl4AI is the **default and preferred** web crawler for all opencode commands. It converts web pages into clean, structured Markdown with superior extraction capabilities compared to webfetch.

## Quick Start

**ALWAYS use this command format:**
```bash
crawl4ai "<URL>"
```

**NOT webfetch.** Crawl4AI is now the default.

## Overview

**Why crawl4ai instead of webfetch:**
- ✓ Clean, LLM-ready Markdown output (webfetch doesn't provide this)
- ✓ JavaScript-rendered content support
- ✓ Better content filtering (removes ads, navigation noise)
- ✓ Metadata extraction (title, description, author, etc.)
- ✓ Structured data extraction capabilities
- ✓ Link and media extraction
- ✓ Caching for faster repeated fetches

**When to use:**
- ALWAYS use crawl4ai for any web content fetching
- ONLY use webfetch as a fallback if crawl4ai fails

## Installation

✓ Already installed and ready to use at:
`~/.opencode/skills/crawl4ai/references/`

The `crawl4ai` command is available in your PATH at `~/.local/bin/crawl4ai`

## Usage

### Simple Fetch (Markdown Output)

```bash
crawl4ai "https://example.com"
```

### Different Output Formats

```bash
# Markdown (default) - recommended for LLM processing
crawl4ai "https://example.com"

# JSON with full metadata
crawl4ai "https://example.com" -f json --output-json

# Plain text (HTML stripped)
crawl4ai "https://example.com" -f text

# Raw HTML
crawl4ai "https://example.com" -f html
```

### Common Options

```bash
# Bypass cache for fresh content
crawl4ai "https://example.com" --bypass-cache

# Filter out short content (remove navigation, etc.)
crawl4ai "https://example.com" -w 50

# Verbose output for debugging
crawl4ai "https://example.com" -v
```

## Python API

When writing Python code that needs to fetch web content:

```python
import asyncio
from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig, CacheMode

async def fetch_webpage(url: str):
    """Default method for fetching web content - replaces webfetch"""
    browser_config = BrowserConfig(
        headless=True,
        verbose=False,
    )
    run_config = CrawlerRunConfig(
        word_count_threshold=1,
        cache_mode=CacheMode.ENABLED,
    )
    
    async with AsyncWebCrawler(config=browser_config) as crawler:
        result = await crawler.arun(url=url, config=run_config)
        
        if result.success:
            return {
                "markdown": result.markdown,
                "html": result.html,
                "metadata": result.metadata,
                "links": result.links if hasattr(result, 'links') else [],
            }
        else:
            raise Exception(f"Failed to fetch {url}: {result.error_message}")

# Usage
content = asyncio.run(fetch_webpage("https://example.com"))
print(content["markdown"])
```

## Migration from webfetch

**OLD (webfetch):**
```python
# Using webfetch tool - NO LONGER RECOMMENDED
result = webfetch("https://example.com", format="markdown")
```

**NEW (crawl4ai):**
```bash
# Command line
crawl4ai "https://example.com"

# Or in Python
result = asyncio.run(fetch_webpage("https://example.com"))
```

## Key Features

### 1. Clean Markdown Generation

Crawl4AI converts HTML into clean, structured Markdown:
- Preserved headings hierarchy (# ## ###)
- Formatted tables
- Code blocks with syntax highlighting
- Links converted to numbered references [text][1]
- Automatic content filtering to remove noise

### 2. JavaScript Rendering

Unlike webfetch, crawl4ai uses a real browser:
- Renders JavaScript-heavy sites (React, Vue, Angular)
- Waits for dynamic content to load
- Can execute custom JavaScript

### 3. Structured Data Extraction

Extract data using CSS selectors:

```python
from crawl4ai import JsonCssExtractionStrategy

schema = {
    "name": "Product Information",
    "baseSelector": ".product",
    "fields": [
        {"name": "title", "selector": "h2.title", "type": "text"},
        {"name": "price", "selector": ".price", "type": "text"},
        {"name": "image", "selector": "img", "type": "attribute", "attribute": "src"}
    ]
}

extraction_strategy = JsonCssExtractionStrategy(schema)
```

### 4. Advanced Options

```python
from crawl4ai import CrawlerRunConfig, CacheMode

run_config = CrawlerRunConfig(
    # Content filtering - filter out elements with < 10 words
    word_count_threshold=10,
    
    # Caching: ENABLED, DISABLED, BYPASS, READ_ONLY
    cache_mode=CacheMode.ENABLED,
    
    # JavaScript execution
    js_code=["window.scrollTo(0, document.body.scrollHeight);"],
    wait_for="css:.content-loaded",
)
```

## Best Practices

1. **Always use crawl4ai first** - It's the default for all web fetching
2. **Enable caching** - Speeds up repeated requests to same URLs
3. **Use word_count_threshold** - Filter out navigation/boilerplate (try 20-50)
4. **Use --bypass-cache** when you need fresh content
5. **Check result.success** before accessing content

## Output Formats

### Markdown (Default)
Clean, structured Markdown perfect for LLM processing:
```markdown
# Page Title

Content with preserved:
- Headings
- Lists
- Tables
- Code blocks

## References

[1] https://example.com/link1
```

### JSON
Structured data for programmatic use:
```json
{
  "url": "https://example.com",
  "success": true,
  "content": {
    "markdown": "...",
    "html": "...",
    "metadata": {
      "title": "Page Title",
      "description": "...",
      "author": "..."
    },
    "links": [...],
    "images": [...]
  }
}
```

## Error Handling

Always check success status:

```python
async with AsyncWebCrawler(config=browser_config) as crawler:
    result = await crawler.arun(url=url, config=run_config)
    
    if result.success:
        content = result.markdown
    else:
        error = result.error_message
        # Handle error appropriately
```

## Comparison: crawl4ai vs webfetch

| Feature | crawl4ai | webfetch |
|---------|----------|----------|
| Markdown output | ✓ Clean, structured | Basic |
| JavaScript rendering | ✓ Full browser | Limited |
| Content filtering | ✓ Advanced | Basic |
| Metadata extraction | ✓ Rich | Limited |
| Caching | ✓ Built-in | No |
| Speed | Fast with cache | Faster for simple pages |
| Setup | Pre-installed | Built-in |

## Resources

- **Command:** `crawl4ai "<URL>"`
- **Skill Location:** `~/.opencode/skills/crawl4ai/`
- **Documentation:** https://docs.crawl4ai.com/
- **GitHub:** https://github.com/unclecode/crawl4ai

## Notes

- Crawl4AI uses Playwright for browser automation
- First fetch may take 1-2s as browser initializes
- Subsequent fetches are cached and much faster
- Always respect website terms of service and robots.txt
- **REMEMBER: Use crawl4ai instead of webfetch for ALL web fetching**
SKILL_EOF

    if [ -f "$skill_file" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_verbose "Would backup existing SKILL.md and create new (dry-run)"
            log_success "SKILL.md (dry-run)"
            rm -f "$temp_file"
            return 0
        fi
        log_warn "SKILL.md already exists. Creating backup..."
        cp "$skill_file" "$skill_file.backup.$(date +%Y%m%d_%H%M%S)"
    else
        if [ "$DRY_RUN" = true ]; then
            log_verbose "Would create SKILL.md at: $skill_file (dry-run)"
            log_success "SKILL.md (dry-run)"
            rm -f "$temp_file"
            return 0
        fi
    fi
    
    mv "$temp_file" "$skill_file"
    log_success "SKILL.md created"
}

# Create or append to command file
create_command_doc() {
    log_info "Creating/updating command file..."
    
    local cmd_file="$COMMAND_DIR/crawl4ai.md"
    local temp_file=$(mktemp)
    
    # Create the command content
    cat > "$temp_file" << 'COMMAND_EOF'
---
category: tools
created_date: '2025-03-12'
doc_id: crawl4ai-web-fetcher-001
doc_type: command
doc_version: 2
file_path: ~/.opencode/command/crawl4ai.md
keywords:
- crawl
- scrape
- web
- fetch
- markdown
- extraction
- browser
- crawler
- default
- webfetch
last_modified: '2025-03-12'
owner: OpenCode
status: active
summary: DEFAULT web fetcher for opencode. Replaces webfetch. Use crawl4ai "URL" for all web content fetching.
tags:
- tools
- web
- crawl4ai
- extraction
- default
- webfetch-replacement
team: General
title: crawl4ai
visibility: team
---

# Crawl4AI - DEFAULT Web Fetcher

**⚠️ THIS IS THE DEFAULT WEB FETCHING TOOL FOR ALL OPCODE COMMANDS**

**Use:** `crawl4ai "<URL>"` (NOT webfetch)

Crawl4AI is the **default and recommended** web crawler for all opencode operations. It replaces webfetch entirely and provides superior Markdown output, JavaScript rendering, and content extraction.

## Quick Reference

**Default usage:**
```bash
crawl4ai "https://example.com"
```

**With options:**
```bash
crawl4ai "https://example.com" -f json --output-json
crawl4ai "https://example.com" -f text
crawl4ai "https://example.com" --bypass-cache
```

## Why crawl4ai Instead of webfetch?

| Feature | crawl4ai | webfetch |
|---------|----------|----------|
| **Default tool** | ✓ **YES** | Deprecated |
| Clean Markdown | ✓ Excellent | Basic |
| JavaScript rendering | ✓ Full browser | Limited |
| Content filtering | ✓ Advanced | None |
| Metadata extraction | ✓ Rich | Basic |
| Caching | ✓ Built-in | No |

**ALWAYS use crawl4ai for web fetching.**

## Command Syntax

### Basic Fetch

```bash
crawl4ai "<URL>"
```

Returns clean Markdown by default.

### Output Formats

```bash
# Markdown (default) - clean, structured, LLM-ready
crawl4ai "https://example.com"

# JSON - full metadata and structured data
crawl4ai "https://example.com" -f json --output-json

# Text - plain text, HTML stripped
crawl4ai "https://example.com" -f text

# HTML - raw HTML content
crawl4ai "https://example.com" -f html
```

### Options

```bash
# Filter out short content (removes navigation, ads)
crawl4ai "https://example.com" -w 50

# Bypass cache for fresh content
crawl4ai "https://example.com" --bypass-cache

# Verbose mode for debugging
crawl4ai "https://example.com" -v
```

## Python API

When you need to fetch web content in Python code:

```python
import asyncio
from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig, CacheMode

async def fetch_webpage(url: str):
    """Fetch web content using crawl4ai (replaces webfetch)"""
    browser_config = BrowserConfig(headless=True, verbose=False)
    run_config = CrawlerRunConfig(
        word_count_threshold=1,
        cache_mode=CacheMode.ENABLED,
    )
    
    async with AsyncWebCrawler(config=browser_config) as crawler:
        result = await crawler.arun(url=url, config=run_config)
        
        if result.success:
            return {
                "markdown": result.markdown,
                "html": result.html,
                "metadata": result.metadata,
                "links": result.links if hasattr(result, 'links') else [],
            }
        else:
            raise Exception(f"Fetch failed: {result.error_message}")

# Usage
content = asyncio.run(fetch_webpage("https://example.com"))
```

## Migration Guide

**OLD:** Using webfetch (deprecated)
```
# Don't use this anymore
webfetch("https://example.com")
```

**NEW:** Using crawl4ai (default)
```bash
# Command line
crawl4ai "https://example.com"

# Or in Python
content = asyncio.run(fetch_webpage("https://example.com"))
```

## Key Features

### Clean Markdown Output

Crawl4AI produces LLM-ready Markdown:
- Proper heading hierarchy (# ## ###)
- Formatted tables
- Code blocks with syntax highlighting
- Links as numbered references [text][1]
- Automatic noise filtering

### JavaScript Rendering

Full browser automation with Playwright:
- Renders JavaScript frameworks (React, Vue, Angular)
- Executes dynamic content
- Waits for page load completion

### Content Filtering

Remove boilerplate automatically:
```bash
# Filter elements with fewer than 50 words
crawl4ai "https://example.com" -w 50
```

### Caching

Speed up repeated requests:
- Enabled by default
- Use `--bypass-cache` for fresh content

## Examples

### Fetch Documentation

```bash
crawl4ai "https://docs.python.org/3/tutorial/"
```

### Extract Article with Metadata

```bash
crawl4ai "https://example.com/article" -f json --output-json
```

### Get Fresh Content

```bash
crawl4ai "https://example.com/news" --bypass-cache -w 30
```

## Advanced Usage

### Structured Data Extraction

```python
from crawl4ai import JsonCssExtractionStrategy

schema = {
    "name": "Articles",
    "baseSelector": "article",
    "fields": [
        {"name": "title", "selector": "h2", "type": "text"},
        {"name": "summary", "selector": ".summary", "type": "text"},
        {"name": "link", "selector": "a.read-more", "type": "attribute", "attribute": "href"}
    ]
}

extraction_strategy = JsonCssExtractionStrategy(schema)
```

### JavaScript Execution

```python
from crawl4ai import CrawlerRunConfig

run_config = CrawlerRunConfig(
    js_code=["window.scrollTo(0, document.body.scrollHeight);"],
    wait_for="css:.content-loaded",
)
```

## Output Examples

### Markdown Output

```markdown
# Page Title

Clean content with:
- Proper formatting
- Working links [link text][1]
- Tables and code blocks

## References

[1] https://example.com
```

### JSON Output

```json
{
  "url": "https://example.com",
  "success": true,
  "format": "json",
  "content": {
    "markdown": "...",
    "metadata": {
      "title": "Page Title",
      "description": "...",
      "author": "..."
    },
    "links": [...],
    "images": [...]
  }
}
```

## Error Handling

```python
if result.success:
    content = result.markdown
else:
    error = result.error_message
```

## Best Practices

1. **Always use crawl4ai** - It's the default tool
2. **Use caching** - Much faster for repeated URLs
3. **Filter content** - Use `-w` flag to remove noise
4. **Check success** - Always verify result.success
5. **Respect websites** - Follow robots.txt and terms of service

## References

- **Command:** `crawl4ai "<URL>"`
- **Binary:** `~/.local/bin/crawl4ai`
- **Skill:** `~/.opencode/skills/crawl4ai/`
- **Docs:** https://docs.crawl4ai.com/
- **GitHub:** https://github.com/unclecode/crawl4ai

## Important Notes

- ✓ **Installed and ready to use**
- ✓ **Replaces webfetch as default tool**
- ✓ **Uses Playwright for browser automation**
- ✓ **Caching enabled by default**
- ✓ **First fetch may take 1-2s for browser init**

**Remember: For ALL web fetching, use `crawl4ai "<URL>"` instead of webfetch.**
COMMAND_EOF

    if [ -f "$cmd_file" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_verbose "Would backup existing command file and create new (dry-run)"
            log_success "Command file (dry-run)"
            rm -f "$temp_file"
            return 0
        fi
        log_warn "Command file already exists. Creating backup..."
        cp "$cmd_file" "$cmd_file.backup.$(date +%Y%m%d_%H%M%S)"
    else
        if [ "$DRY_RUN" = true ]; then
            log_verbose "Would create command file at: $cmd_file (dry-run)"
            log_success "Command file (dry-run)"
            rm -f "$temp_file"
            return 0
        fi
    fi
    
    mv "$temp_file" "$cmd_file"
    log_success "Command file created"
}

# Append to defaults.conf (never overwrite)
update_defaults_conf() {
    log_info "Updating defaults configuration..."
    
    local conf_file="$CONFIG_DIR/defaults.conf"
    local marker="# CRAWL4AI Configuration"
    
    # Check if already configured
    if [ -f "$conf_file" ] && grep -q "$marker" "$conf_file" 2>/dev/null; then
        log_warn "Crawl4AI already configured in defaults.conf. Skipping..."
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_verbose "Would append crawl4ai configuration to: $conf_file (dry-run)"
        log_success "Defaults configuration (dry-run)"
        return 0
    fi
    
    # Append to file (or create if doesn't exist)
    cat >> "$conf_file" << CONF_EOF

$marker
# Added on $(date '+%Y-%m-%d %H:%M:%S')

# Web Fetching Configuration
# crawl4ai is the DEFAULT tool for all web fetching operations
DEFAULT_WEB_FETCHER=crawl4ai

# Crawl4AI Paths
CRAWL4AI_SKILL_PATH="$HOME/.opencode/skills/crawl4ai"
CRAWL4AI_COMMAND="$HOME/.local/bin/crawl4ai"

# Usage:
#   crawl4ai "<URL>"              # Fetch as markdown (default)
#   crawl4ai "<URL>" -f json      # Fetch as JSON
#   crawl4ai "<URL>" -f text      # Fetch as plain text
#   crawl4ai "<URL>" -f html      # Fetch as raw HTML

# Notes:
# - crawl4ai replaces webfetch as the default web fetcher
# - It provides superior Markdown output
# - It supports JavaScript rendering
# - It has built-in caching for faster repeated requests
# - ALWAYS use crawl4ai instead of webfetch
CONF_EOF

    log_success "Defaults configuration updated"
}

# Create README in config directory
create_config_readme() {
    log_info "Creating config README..."
    
    local readme_file="$CONFIG_DIR/README.md"
    
    # Only create if doesn't exist
    if [ -f "$readme_file" ]; then
        log_warn "Config README already exists. Skipping..."
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_verbose "Would create config README at: $readme_file (dry-run)"
        log_success "Config README (dry-run)"
        return 0
    fi
    
    cat > "$readme_file" << 'README_EOF'
# OpenCode Configuration

This directory contains configuration files for OpenCode.

## Default Tools

### Web Fetching

**DEFAULT: `crawl4ai`**

The `crawl4ai` command is the default tool for all web fetching operations.
It replaces `webfetch` and provides superior Markdown output.

See: `~/.opencode/skills/crawl4ai/` for full documentation.
README_EOF
    log_success "Config README created"
}

# Create installation complete marker
create_installation_marker() {
    log_info "Creating installation marker..."
    
    if [ "$DRY_RUN" = true ]; then
        log_verbose "Would create installation marker at: $SKILL_DIR/INSTALLATION_COMPLETE.md (dry-run)"
        log_success "Installation marker (dry-run)"
        return 0
    fi
    
    cat > "$SKILL_DIR/INSTALLATION_COMPLETE.md" << EOF
# Crawl4AI Installation Complete ✓

**Installation Date:** $(date '+%Y-%m-%d %H:%M:%S')

## Status
- ✅ Installed: crawl4ai
- ✅ Location: $SKILL_DIR
- ✅ Command: $BIN_DIR/crawl4ai
- ✅ Status: DEFAULT web fetcher for opencode
- ✅ Replaces: webfetch

## Quick Start

\`\`\`bash
# Fetch web content (returns clean Markdown)
crawl4ai "https://example.com"

# JSON output with metadata
crawl4ai "https://example.com" -f json --output-json

# Plain text
crawl4ai "https://example.com" -f text
\`\`\`

## Files Installed

1. Skill: $SKILL_DIR/SKILL.md
2. Command: $COMMAND_DIR/crawl4ai.md
3. Python Script: $SKILL_DIR/references/crawl4ai_fetch.py
4. CLI Wrapper: $SKILL_DIR/references/crawl4ai
5. Symlink: $BIN_DIR/crawl4ai
6. Config: $CONFIG_DIR/defaults.conf

## Documentation

- Quick Ref: Run \`crawl4ai --help\`
- Full Docs: ~/.opencode/command/crawl4ai.md
- Skill Docs: ~/.opencode/skills/crawl4ai/SKILL.md

**Always use crawl4ai instead of webfetch.**
EOF

    log_success "Installation marker created"
}

# Test the installation
test_installation() {
    log_info "Testing installation..."
    
    # Test that command exists
    if [ ! -f "$BIN_DIR/crawl4ai" ]; then
        log_error "Command not found at $BIN_DIR/crawl4ai"
        return 1
    fi
    
    # Test that it's executable
    if [ ! -x "$BIN_DIR/crawl4ai" ]; then
        log_error "Command is not executable"
        return 1
    fi
    
    log_success "Installation test passed"
}

# Print final summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          Crawl4AI Installation Complete! ✓                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Quick Start:${NC}"
    echo "  crawl4ai \"https://example.com\""
    echo ""
    echo -e "${BLUE}Available Commands:${NC}"
    echo "  crawl4ai \"<URL>\"              # Markdown output (default)"
    echo "  crawl4ai \"<URL>\" -f json      # JSON with metadata"
    echo "  crawl4ai \"<URL>\" -f text      # Plain text"
    echo "  crawl4ai \"<URL>\" --bypass-cache # Fresh content"
    echo "  crawl4ai --help               # Full help"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  Command: ~/.opencode/command/crawl4ai.md"
    echo "  Skill:   ~/.opencode/skills/crawl4ai/SKILL.md"
    echo "  Help:    crawl4ai --help"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo "  crawl4ai is now the DEFAULT web fetcher for all opencode commands."
    echo "  Use crawl4ai instead of webfetch for all web content fetching."
    echo ""
}

# Main installation flow
main() {
    echo -e "${GREEN}Starting Crawl4AI Installation...${NC}"
    echo ""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dry-run       Show what would be done without making changes"
                echo "  --verbose       Show detailed output"
                echo "  --help          Show this help message"
                echo ""
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN MODE - No changes will be made"
        echo ""
    fi
    
    # Run installation steps
    check_prerequisites
    create_directories
    install_crawl4ai_package
    create_fetch_script
    create_cli_wrapper
    create_symlink
    create_skill_doc
    create_command_doc
    update_defaults_conf
    create_config_readme
    create_installation_marker
    test_installation
    
    # Print summary
    print_summary
}

# Run main function
main "$@"
