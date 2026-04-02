# OpenCode AI Skills Setup Guide

This guide explains how to set up a professional website development environment using **Stitch**, **NanoBanana**, and **UI UX Pro Max** skills with OpenCode.

## Overview

These three AI-powered tools work together to create professionally designed websites:

- **Stitch MCP**: AI-powered UI/UX design generation from Google
- **Nano Banana 2**: AI image generation using Google's Gemini models
- **UI UX Pro Max**: Design intelligence with 67+ styles, color palettes, fonts, and best practices

## Prerequisites

Ensure you have the following installed:

- **Node.js 18+** and npm
- **Python 3**
- **Git**
- **OpenCode** AI editor

## Step 1: Get API Keys (Required Before Installation)

The installer will prompt you for these API keys during installation. Get them ready first:

### Stitch API Key
1. Visit: https://stitch.withgoogle.com
2. Sign up and create an API key
3. Keep the key ready to paste during installation

### Google Gemini API Key
1. Visit: https://makersuite.google.com/app/apikey
2. Create a new API key
3. Keep the key ready to paste during installation

**Note:** You can skip providing keys during install and add them later to `~/opencode.json`, but the skills won't work until keys are configured.

## Step 2: Download the Installer

```bash
curl -fsSL https://snip.murylo.co.uk/rykou/a8c79e2e20e0479e82bd3d3e6a98b76f > install-opencode-skills.sh
chmod +x install-opencode-skills.sh
```

## Step 3: Run the Installer

```bash
./install-opencode-skills.sh
```

The script will:
- Check and install missing dependencies
- **Prompt for your API keys** (have them ready from Step 1)
- Backup existing OpenCode configuration
- Install all three skills
- Update `~/opencode.json` configuration

## Step 4: Restart OpenCode

After installation completes, restart OpenCode to load the new skills.

## Usage with 21st.dev

### Method 1: Using Prompts from 21st.dev

1. Visit https://21st.dev and browse components/designs
2. Copy a prompt or design description
3. In OpenCode, use Stitch to generate the design:
   ```
   "Generate a landing page like [21st.dev design] using Stitch and nanobanana"
   ```

#

## Workflow Example

1. **Research**: Use UI UX Pro Max to find design patterns:
   ```bash
   python3 ~/.opencode/skills/ui-ux-pro-max/scripts/search.py "SaaS landing page" --domain landing
   ```

2. **Design**: Generate UI mockups with Stitch:
   ```
   "Create a modern SaaS landing page with hero section, features, and CTA using Stitch"
   ```

3. **Assets**: Generate images with NanoBanana:
   ```
   "Generate a hero image for my SaaS product using NanoBanana: abstract tech background"
   ```

4. **Implement**: Use OpenCode to build the website with the generated designs and assets

## Troubleshooting

### Skills Not Loading
- Verify `~/opencode.json` exists and is valid JSON
- Check that API keys are correctly set
- Restart OpenCode after configuration changes

### Missing Dependencies
The installer will attempt to install missing dependencies. If it fails:

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y nodejs npm python3 git

# macOS
brew install node python git

# Arch
sudo pacman -S --noconfirm nodejs npm python git
```

### Backup and Restore
The installer creates backups at `~/.opencode/backups/`. To restore:

```bash
cp -r ~/.opencode/backups/[timestamp]/* ~/.opencode/
```

## File Locations

- **Config**: `~/opencode.json`
- **Skills**: `~/.opencode/skills/`
- **NanoBanana**: `~/nanobanana-extension/`
- **Backups**: `~/.opencode/backups/`

## Next Steps

1. Test the skills: "Generate a landing page using Stitch"
2. Explore 21st.dev for inspiration and prompts
3. Start building professional websites with AI-powered design

---

**Note**: If you skipped providing API keys during installation, you'll need to manually add them to `~/opencode.json` before the skills will work.
