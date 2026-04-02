#!/bin/bash

# OpenCode AI Skills Installer
# Installs: Stitch MCP, Nano Banana 2, UI UX Pro Max
# Author: Murylo Batista
# Version: 1.1.0

set -euo pipefail

# ============================================================================
# COLORS AND FORMATTING
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# Emojis
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"
GEAR="⚙️"
KEY="🔑"
PACKAGE="📦"
WRENCH="🔧"
SPARKLES="✨"
LOCK="🔒"

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.opencode/backups/$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="$(mktemp -d)"
SUDO_PASSWORD=""
SUDO_AVAILABLE=false

# Repository URLs
NANOBANANA_REPO="https://github.com/gemini-cli-extensions/nanobanana.git"
UIPPMAX_REPO="https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git"

# Installation paths
OPENCODE_DIR="$HOME/.opencode"
SKILLS_DIR="$OPENCODE_DIR/skills"
CONFIG_FILE="$HOME/opencode.json"

# Skills info
declare -A SKILL_NAMES
SKILL_NAMES[stitch]="Stitch MCP"
SKILL_NAMES[nanobanana]="Nano Banana 2"
SKILL_NAMES[uiuxpromax]="UI UX Pro Max"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                                                              ║${NC}"
    echo -e "${CYAN}${BOLD}║${NC}     ${WHITE}${BOLD}🚀 OpenCode AI Skills Installer${NC}                       ${CYAN}${BOLD}║${NC}"
    echo -e "${CYAN}${BOLD}║${NC}     ${DIM}Stitch MCP • Nano Banana 2 • UI UX Pro Max${NC}            ${CYAN}${BOLD}║${NC}"
    echo -e "${CYAN}${BOLD}║                                                              ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}${BOLD}$GEAR $1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_error() {
    echo -e "${RED}${CROSS} $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

print_info() {
    echo -e "${CYAN}${INFO} $1${NC}"
}

print_prompt() {
    echo -e "${MAGENTA}${BOLD}$KEY $1${NC}"
}

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# ============================================================================
# SUDO MANAGEMENT
# ============================================================================

check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        echo ""
        print_error "Do NOT run this script as root or with sudo!"
        echo ""
        print_info "This script will prompt for your password only when needed"
        print_info "to install system dependencies. All user files will be installed"
        print_info "in your home directory: $HOME"
        echo ""
        exit 1
    fi
}

check_sudo_available() {
    if command -v sudo &> /dev/null; then
        # Check if user has sudo access
        if sudo -n true 2>/dev/null; then
            SUDO_AVAILABLE=true
            print_success "Sudo access available (passwordless)"
        elif sudo -l >/dev/null 2>&1; then
            SUDO_AVAILABLE=true
            print_info "Sudo access available (password required)"
        else
            SUDO_AVAILABLE=false
            print_warning "Sudo not available. Will try to install without elevated privileges."
        fi
    else
        SUDO_AVAILABLE=false
        print_warning "Sudo command not found. Will try to install without elevated privileges."
    fi
}

request_sudo_password() {
    if [[ "$SUDO_AVAILABLE" == false ]]; then
        return 1
    fi
    
    # Check if we can run sudo without password
    if sudo -n true 2>/dev/null; then
        return 0
    fi
    
    # Need password
    echo ""
    print_prompt "Administrator privileges required"
    echo -e "${DIM}Your password is needed to install system packages.${NC}"
    echo -e "${DIM}It will not be stored and is only used for this installation.${NC}"
    echo ""
    
    local attempts=0
    local max_attempts=3
    
    while [[ $attempts -lt $max_attempts ]]; do
        read -s -p "$(echo -e "${MAGENTA}${LOCK} Enter sudo password: ${NC}")" SUDO_PASSWORD
        echo ""
        
        # Test the password
        if echo "$SUDO_PASSWORD" | sudo -S true 2>/dev/null; then
            print_success "Password accepted"
            return 0
        else
            attempts=$((attempts + 1))
            if [[ $attempts -lt $max_attempts ]]; then
                print_error "Incorrect password. Try again ($attempts/$max_attempts)"
            fi
        fi
    done
    
    print_error "Failed to authenticate after $max_attempts attempts"
    SUDO_PASSWORD=""
    return 1
}

run_with_sudo() {
    if [[ -n "$SUDO_PASSWORD" ]]; then
        echo "$SUDO_PASSWORD" | sudo -S "$@"
    else
        sudo "$@"
    fi
}

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================

check_prerequisites() {
    print_section "Checking Prerequisites"
    
    local missing_deps=()
    local install_commands=()
    local package_manager=""
    
    # Detect package manager
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            package_manager="apt"
        elif command -v yum &> /dev/null; then
            package_manager="yum"
        elif command -v dnf &> /dev/null; then
            package_manager="dnf"
        elif command -v pacman &> /dev/null; then
            package_manager="pacman"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            package_manager="brew"
        fi
    fi
    
    # Check Node.js
    if command -v node &> /dev/null; then
        local node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$node_version" -ge 18 ]]; then
            print_success "Node.js $(node --version) installed"
        else
            print_warning "Node.js $(node --version) found (18+ recommended)"
        fi
    else
        missing_deps+=("nodejs")
        case $package_manager in
            apt) install_commands+=("apt-get install -y nodejs npm") ;;
            yum) install_commands+=("yum install -y nodejs npm") ;;
            dnf) install_commands+=("dnf install -y nodejs npm") ;;
            pacman) install_commands+=("pacman -S --noconfirm nodejs npm") ;;
            brew) install_commands+=("brew install node") ;;
            *) install_commands+=("[manual] Install Node.js 18+ from https://nodejs.org") ;;
        esac
    fi
    
    # Check npm/npx
    if command -v npx &> /dev/null; then
        print_success "npm/npx installed"
    else
        missing_deps+=("npm")
        # npm usually installed with nodejs
    fi
    
    # Check Python 3
    if command -v python3 &> /dev/null; then
        local py_version=$(python3 --version | cut -d' ' -f2)
        print_success "Python $py_version installed"
    else
        missing_deps+=("python3")
        case $package_manager in
            apt) install_commands+=("apt-get install -y python3") ;;
            yum) install_commands+=("yum install -y python3") ;;
            dnf) install_commands+=("dnf install -y python3") ;;
            pacman) install_commands+=("pacman -S --noconfirm python") ;;
            brew) install_commands+=("brew install python") ;;
            *) install_commands+=("[manual] Install Python 3 from https://python.org") ;;
        esac
    fi
    
    # Check Git
    if command -v git &> /dev/null; then
        print_success "Git $(git --version | cut -d' ' -f3) installed"
    else
        missing_deps+=("git")
        case $package_manager in
            apt) install_commands+=("apt-get install -y git") ;;
            yum) install_commands+=("yum install -y git") ;;
            dnf) install_commands+=("dnf install -y git") ;;
            pacman) install_commands+=("pacman -S --noconfirm git") ;;
            brew) install_commands+=("brew install git") ;;
            *) install_commands+=("[manual] Install Git from https://git-scm.com") ;;
        esac
    fi
    
    # Handle missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo ""
        print_warning "Missing dependencies: ${missing_deps[*]}"
        
        if [[ ${#install_commands[@]} -gt 0 ]]; then
            echo ""
            echo -e "${WHITE}Installation commands:${NC}"
            for cmd in "${install_commands[@]}"; do
                echo -e "  ${DIM}$cmd${NC}"
            done
            echo ""
            
            read -p "$(echo -e "${MAGENTA}Install missing dependencies? [Y/n]: ${NC}")" -n 1 -r
            echo ""
            
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                install_dependencies "$package_manager" "${missing_deps[@]}"
            else
                print_error "Cannot continue without required dependencies"
                exit 1
            fi
        else
            print_error "Please install missing dependencies manually"
            exit 1
        fi
    fi
}

install_dependencies() {
    local package_manager=$1
    shift
    local deps=("$@")
    
    echo ""
    print_info "Installing dependencies: ${deps[*]}"
    
    # Request sudo password if needed
    if ! request_sudo_password; then
        print_error "Cannot install dependencies without administrator privileges"
        print_info "Please install manually: ${deps[*]}"
        exit 1
    fi
    
    case $package_manager in
        apt)
            print_info "Updating package list..."
            run_with_sudo apt-get update
            print_info "Installing packages..."
            run_with_sudo apt-get install -y nodejs npm python3 git
            ;;
        yum)
            run_with_sudo yum install -y nodejs npm python3 git
            ;;
        dnf)
            run_with_sudo dnf install -y nodejs npm python3 git
            ;;
        pacman)
            run_with_sudo pacman -S --noconfirm nodejs npm python git
            ;;
        brew)
            # Homebrew doesn't need sudo
            brew install node python git
            ;;
        *)
            print_error "Cannot auto-install on this system"
            print_info "Please install manually: ${deps[*]}"
            exit 1
            ;;
    esac
    
    print_success "Dependencies installed successfully"
}

# ============================================================================
# CONFIGURATION WIZARD
# ============================================================================

configuration_wizard() {
    print_section "Configuration Wizard"
    
    echo -e "${WHITE}This wizard will help you configure the AI skills for OpenCode.${NC}"
    echo -e "${DIM}You can leave fields empty and edit the configuration files later.${NC}"
    echo ""
    
    # Stitch API Key
    print_prompt "Stitch MCP Configuration"
    echo -e "${DIM}Stitch provides AI-powered UI/UX design generation.${NC}"
    echo -e "${DIM}Get your API key from: https://stitch.withgoogle.com${NC}"
    echo ""
    read -p "$(echo -e "${MAGENTA}Stitch API Key (optional): ${NC}")" STITCH_API_KEY
    
    if [[ -z "$STITCH_API_KEY" ]]; then
        print_warning "No Stitch API key provided. You'll need to add it later to: $CONFIG_FILE"
    fi
    
    echo ""
    
    # Gemini API Key
    print_prompt "Nano Banana 2 Configuration"
    echo -e "${DIM}Nano Banana 2 provides AI image generation using Google's Gemini.${NC}"
    echo -e "${DIM}Get your API key from: https://makersuite.google.com/app/apikey${NC}"
    echo ""
    read -p "$(echo -e "${MAGENTA}Google Gemini API Key (optional): ${NC}")" GEMINI_API_KEY
    
    if [[ -z "$GEMINI_API_KEY" ]]; then
        print_warning "No Gemini API key provided. You'll need to add it later to: $CONFIG_FILE"
    fi
    
    echo ""
    
    # Summary
    print_section "Configuration Summary"
    
    if [[ -n "$STITCH_API_KEY" ]]; then
        print_success "Stitch API Key: ${STITCH_API_KEY:0:10}..."
    else
        print_warning "Stitch API Key: (not set)"
    fi
    
    if [[ -n "$GEMINI_API_KEY" ]]; then
        print_success "Gemini API Key: ${GEMINI_API_KEY:0:10}..."
    else
        print_warning "Gemini API Key: (not set)"
    fi
    
    echo ""
    read -p "$(echo -e "${MAGENTA}Proceed with installation? [Y/n]: ${NC}")" -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_error "Installation cancelled"
        exit 1
    fi
}

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================

backup_existing() {
    print_section "Backing Up Existing Configuration"
    
    mkdir -p "$BACKUP_DIR"
    
    local backed_up=false
    
    # Backup existing skills directory
    if [[ -d "$SKILLS_DIR" ]]; then
        print_info "Backing up existing skills..."
        cp -r "$SKILLS_DIR" "$BACKUP_DIR/"
        print_success "Skills backed up to: $BACKUP_DIR/skills"
        backed_up=true
    fi
    
    # Backup existing config file
    if [[ -f "$CONFIG_FILE" ]]; then
        print_info "Backing up existing config..."
        cp "$CONFIG_FILE" "$BACKUP_DIR/opencode.json"
        print_success "Config backed up to: $BACKUP_DIR/opencode.json"
        backed_up=true
    fi
    
    if [[ "$backed_up" == false ]]; then
        print_info "No existing configuration to backup"
    else
        echo ""
        print_warning "Backup created at: $BACKUP_DIR"
        print_info "You can restore using: cp -r $BACKUP_DIR/* ~/.opencode/"
    fi
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

install_stitch_mcp() {
    print_section "Installing Stitch MCP"
    
    print_info "Stitch MCP will be configured to use npx..."
    
    # Stitch doesn't need local installation, just npx
    # It will be configured in the opencode.json file
    
    print_success "Stitch MCP configured (uses npx @_davideast/stitch-mcp)"
}

install_nanobanana() {
    print_section "Installing Nano Banana 2"
    
    local install_dir="$HOME/nanobanana-extension"
    
    # Remove existing installation if present
    if [[ -d "$install_dir" ]]; then
        print_info "Removing existing Nano Banana installation..."
        rm -rf "$install_dir"
    fi
    
    # Clone repository
    print_info "Cloning Nano Banana repository..."
    git clone --depth 1 "$NANOBANANA_REPO" "$install_dir" 2>&1 | while read line; do
        echo -e "${DIM}  $line${NC}"
    done
    
    # Build MCP server
    print_info "Building MCP server..."
    cd "$install_dir/mcp-server"
    npm install 2>&1 | grep -v "^npm WARN" | while read line; do
        echo -e "${DIM}  $line${NC}"
    done
    npm run build 2>&1 | while read line; do
        echo -e "${DIM}  $line${NC}"
    done
    
    cd "$SCRIPT_DIR"
    
    print_success "Nano Banana 2 installed to: $install_dir"
}

install_uiuxpromax() {
    print_section "Installing UI UX Pro Max"
    
    local skill_dir="$SKILLS_DIR/ui-ux-pro-max"
    
    # Remove existing installation
    if [[ -d "$skill_dir" ]]; then
        print_info "Removing existing UI UX Pro Max..."
        rm -rf "$skill_dir"
    fi
    
    # Clone repository
    print_info "Cloning UI UX Pro Max repository..."
    git clone --depth 1 "$UIPPMAX_REPO" "$TEMP_DIR/uipro-skill" 2>&1 | while read line; do
        echo -e "${DIM}  $line${NC}"
    done
    
    # Create skill directory
    mkdir -p "$skill_dir"
    
    # Copy data and scripts
    print_info "Installing skill files..."
    cp -r "$TEMP_DIR/uipro-skill/src/ui-ux-pro-max/data" "$skill_dir/"
    cp -r "$TEMP_DIR/uipro-skill/src/ui-ux-pro-max/scripts" "$skill_dir/"
    
    # Create SKILL.md
    cat > "$skill_dir/SKILL.md" << 'EOF'
---
name: ui-ux-pro-max
description: UI/UX design intelligence with searchable database
---

# UI UX Pro Max

Comprehensive design guide for web and mobile applications. Contains 67 styles, 96 color palettes, 57 font pairings, 99 UX guidelines, and 25 chart types across 13 technology stacks. Searchable database with priority-based recommendations.

## Prerequisites

```bash
python3 --version || python --version
```

Install if needed:
- **macOS:** `brew install python3`
- **Ubuntu/Debian:** `sudo apt update && sudo apt install python3`
- **Windows:** `winget install Python.Python.3.12`

## Usage

Generate a design system:
```bash
python3 ~/.opencode/skills/ui-ux-pro-max/scripts/search.py "<product_type> <industry>" --design-system -p "Project Name"
```

**Example:**
```bash
python3 ~/.opencode/skills/ui-ux-pro-max/scripts/search.py "fintech app modern" --design-system -p "MyApp"
```

### Domain Searches

- `product` - Product type recommendations
- `style` - UI styles (glassmorphism, minimalism, etc.)
- `typography` - Font pairings
- `color` - Color palettes
- `landing` - Landing page patterns
- `chart` - Chart types
- `ux` - Best practices
- `stack` - Stack-specific guidelines

### Available Stacks

`html-tailwind` (default), `react`, `nextjs`, `vue`, `svelte`, `swiftui`, `react-native`, `flutter`, `shadcn`, `jetpack-compose`

See full documentation in the skill directory.
EOF

    print_success "UI UX Pro Max installed to: $skill_dir"
}

# ============================================================================
# CONFIGURATION FILE MANAGEMENT
# ============================================================================

update_opencode_config() {
    print_section "Updating OpenCode Configuration"
    
    # Create new config structure
    local new_config='{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "stitch": {
      "type": "local",
      "command": ["npx", "@_davideast/stitch-mcp", "proxy"],
      "environment": {
        "STITCH_API_KEY": "'
    
    if [[ -n "$STITCH_API_KEY" ]]; then
        new_config+="$STITCH_API_KEY"
    else
        new_config+="YOUR_STITCH_API_KEY_HERE"
    fi
    
    new_config+='"
      }
    },
    "nanobanana": {
      "type": "local",
      "command": ["node", "'
    new_config+="$HOME/nanobanana-extension/mcp-server/dist/index.js"
    new_config+='"],
      "environment": {
        "GEMINI_API_KEY": "'
    
    if [[ -n "$GEMINI_API_KEY" ]]; then
        new_config+="$GEMINI_API_KEY"
    else
        new_config+="YOUR_GEMINI_API_KEY_HERE"
    fi
    
    new_config+='"
      }
    }
  }
}'
    
    # Check if config file exists
    if [[ -f "$CONFIG_FILE" ]]; then
        print_info "Existing config found. Merging configurations..."
        
        # Save the new config to a temp file
        echo "$new_config" > "$TEMP_DIR/new_opencode.json"
        
        # Create merge script
        python3 << PYTHON_SCRIPT
import json
import sys

try:
    # Read existing config
    with open('$CONFIG_FILE', 'r') as f:
        existing = json.load(f)
except:
    existing = {}

# Read new config
with open('$TEMP_DIR/new_opencode.json', 'r') as f:
    new_config = json.load(f)

# Merge MCP configurations
if 'mcp' not in existing:
    existing['mcp'] = {}

# Add or update MCP servers
for key, value in new_config.get('mcp', {}).items():
    existing['mcp'][key] = value

# Ensure schema is set
existing['\$schema'] = new_config.get('\$schema', 'https://opencode.ai/config.json')

# Write merged config
with open('$CONFIG_FILE', 'w') as f:
    json.dump(existing, f, indent=2)

print('Configuration merged successfully')
PYTHON_SCRIPT

        print_success "Configuration merged: $CONFIG_FILE"
    else
        # Create new config file
        echo "$new_config" > "$CONFIG_FILE"
        print_success "Configuration created: $CONFIG_FILE"
    fi
    
    # Display config file location
    echo ""
    print_info "Configuration file location: $CONFIG_FILE"
    
    if [[ -z "$STITCH_API_KEY" ]] || [[ -z "$GEMINI_API_KEY" ]]; then
        echo ""
        print_warning "Remember to add your API keys to the config file!"
        echo -e "${DIM}Edit: $CONFIG_FILE${NC}"
    fi
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_installation() {
    print_section "Verifying Installation"
    
    local all_good=true
    
    # Check Stitch MCP (npx)
    if command -v npx &> /dev/null; then
        print_success "Stitch MCP: npx available"
    else
        print_error "Stitch MCP: npx not found"
        all_good=false
    fi
    
    # Check Nano Banana 2
    if [[ -f "$HOME/nanobanana-extension/mcp-server/dist/index.js" ]]; then
        print_success "Nano Banana 2: Files installed"
    else
        print_error "Nano Banana 2: Files not found"
        all_good=false
    fi
    
    # Check UI UX Pro Max
    if [[ -f "$SKILLS_DIR/ui-ux-pro-max/scripts/search.py" ]]; then
        print_success "UI UX Pro Max: Files installed"
        
        # Test the search script
        print_info "Testing UI UX Pro Max search functionality..."
        if python3 "$SKILLS_DIR/ui-ux-pro-max/scripts/search.py" "test" --domain style -n 1 &> /dev/null; then
            print_success "UI UX Pro Max: Search functionality working"
        else
            print_warning "UI UX Pro Max: Search test failed (may need Python dependencies)"
        fi
    else
        print_error "UI UX Pro Max: Files not found"
        all_good=false
    fi
    
    # Check config file
    if [[ -f "$CONFIG_FILE" ]]; then
        print_success "OpenCode config: File exists"
    else
        print_error "OpenCode config: File not found"
        all_good=false
    fi
    
    echo ""
    if [[ "$all_good" == true ]]; then
        print_success "All verifications passed!"
    else
        print_warning "Some verifications failed. Check the errors above."
    fi
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
    print_section "Installation Complete!"
    
    echo -e "${GREEN}${BOLD}$SPARKLES OpenCode AI Skills installed successfully!${NC}"
    echo ""
    
    echo -e "${WHITE}${BOLD}Installed Skills:${NC}"
    echo -e "  ${CHECK} ${SKILL_NAMES[stitch]} - UI/UX design generation"
    echo -e "  ${CHECK} ${SKILL_NAMES[nanobanana]} - AI image generation"
    echo -e "  ${CHECK} ${SKILL_NAMES[uiuxpromax]} - Design intelligence"
    echo ""
    
    echo -e "${WHITE}${BOLD}Configuration:${NC}"
    echo -e "  ${INFO} Config file: ${CYAN}$CONFIG_FILE${NC}"
    echo -e "  ${INFO} Skills directory: ${CYAN}$SKILLS_DIR${NC}"
    
    if [[ -d "$BACKUP_DIR" ]]; then
        echo -e "  ${INFO} Backup location: ${CYAN}$BACKUP_DIR${NC}"
    fi
    
    echo ""
    
    if [[ -z "$STITCH_API_KEY" ]] || [[ -z "$GEMINI_API_KEY" ]]; then
        echo -e "${YELLOW}${BOLD}⚠️  Action Required:${NC}"
        echo ""
        if [[ -z "$STITCH_API_KEY" ]]; then
            echo -e "  ${KEY} Add Stitch API key:"
            echo -e "     Edit: ${CYAN}$CONFIG_FILE${NC}"
            echo -e "     Get key: ${CYAN}https://stitch.withgoogle.com${NC}"
            echo ""
        fi
        if [[ -z "$GEMINI_API_KEY" ]]; then
            echo -e "  ${KEY} Add Gemini API key:"
            echo -e "     Edit: ${CYAN}$CONFIG_FILE${NC}"
            echo -e "     Get key: ${CYAN}https://makersuite.google.com/app/apikey${NC}"
            echo ""
        fi
    fi
    
    echo -e "${WHITE}${BOLD}Next Steps:${NC}"
    echo -e "  1. ${ROCKET} Restart OpenCode to load the new skills"
    echo -e "  2. ${PACKAGE} Test with: 'Generate a landing page using Stitch'"
    echo -e "  3. ${WRENCH} Generate design systems: 'python3 $SKILLS_DIR/ui-ux-pro-max/scripts/search.py \"SaaS app\" --design-system'"
    echo ""
    
    echo -e "${CYAN}${BOLD}Happy coding! 🎉${NC}"
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header
    
    # Check not running as root
    check_not_root
    
    # Check if sudo is available
    check_sudo_available
    
    # Check prerequisites
    check_prerequisites
    
    # Run configuration wizard
    configuration_wizard
    
    # Backup existing configuration
    backup_existing
    
    # Install skills
    install_stitch_mcp
    install_nanobanana
    install_uiuxpromax
    
    # Update configuration
    update_opencode_config
    
    # Verify installation
    verify_installation
    
    # Print summary
    print_summary
}

# Run main function
main
