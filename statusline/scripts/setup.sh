#!/bin/bash
# Claude Code Statusline - Setup Script
# Installs dependencies and configures settings.json
#
# Usage: ./setup.sh [--check-only]
#   --check-only  Only check dependencies, don't install or configure
#
# Supported platforms:
#   - Linux (apt, dnf, yum, pacman, zypper, apk)
#   - macOS (Homebrew)
#   - Windows (WSL - uses apt)

set -eo pipefail

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# ALWAYS prefer marketplaces over cache for settings.json (live updates)
# Cache is for versioned snapshots only - marketplaces gets git pull updates
if [[ "$SCRIPT_DIR" == *"/cache/"* ]]; then
    # Convert: /cache/marketplace-name/plugin-name/version/scripts → /marketplaces/marketplace-name/plugin-name/scripts
    MARKETPLACE_PATH="${SCRIPT_DIR/\/cache\//\/marketplaces\/}"
    # Remove version directory from path (e.g., /1.0.0/)
    MARKETPLACE_PATH=$(echo "$MARKETPLACE_PATH" | sed 's|/[0-9]\+\.[0-9]\+\.[0-9]\+/|/|')

    if [ -d "$MARKETPLACE_PATH" ]; then
        echo -e "Converting cache path to marketplaces path for live updates..."
        SCRIPT_DIR="$MARKETPLACE_PATH"
        PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi
fi

# Source colors or use fallback
if [ -f "$SCRIPT_DIR/colors.sh" ]; then
    source "$SCRIPT_DIR/colors.sh"
else
    COLOR_BLUE='\033[38;2;0;114;178m'
    COLOR_GREEN='\033[38;2;0;158;115m'
    COLOR_ORANGE='\033[38;2;230;159;0m'
    COLOR_RED='\033[38;2;204;51;17m'
    COLOR_GREY='\033[38;2;187;187;187m'
    NC='\033[0m'
fi

# Symbols
SYM_OK="${COLOR_GREEN}[OK]${NC}"
SYM_WARN="${COLOR_ORANGE}[!]${NC}"
SYM_ERR="${COLOR_RED}[X]${NC}"
SYM_INFO="${COLOR_BLUE}[i]${NC}"

# Paths
STATUSLINE_SCRIPT="$SCRIPT_DIR/statusline-command.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Parse arguments
CHECK_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --check-only) CHECK_ONLY=1 ;;
    esac
done

# Detect OS and package manager
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Check for WSL
        if grep -qi microsoft /proc/version 2>/dev/null; then
            echo "wsl"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v brew &>/dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# Install a package using the appropriate package manager
install_package() {
    local pkg=$1
    local pm=$(detect_package_manager)

    echo -e "${SYM_INFO} Installing $pkg using $pm..."

    case "$pm" in
        apt)
            sudo apt-get update -qq && sudo apt-get install -y "$pkg"
            ;;
        dnf)
            sudo dnf install -y "$pkg"
            ;;
        yum)
            sudo yum install -y "$pkg"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$pkg"
            ;;
        zypper)
            sudo zypper install -y "$pkg"
            ;;
        apk)
            sudo apk add "$pkg"
            ;;
        brew)
            brew install "$pkg"
            ;;
        *)
            echo -e "${SYM_ERR} Unknown package manager. Please install $pkg manually."
            return 1
            ;;
    esac
}

# Check and install dependencies
check_dependencies() {
    local missing=()

    echo -e "${COLOR_BLUE}Checking dependencies...${NC}"

    # Check jq (required)
    if command -v jq &>/dev/null; then
        echo -e "  ${SYM_OK} jq $(jq --version 2>/dev/null || echo 'installed')"
    else
        echo -e "  ${SYM_WARN} jq not found (required)"
        missing+=("jq")
    fi

    # Check git (optional but recommended)
    if command -v git &>/dev/null; then
        echo -e "  ${SYM_OK} git $(git --version 2>/dev/null | head -1)"
    else
        echo -e "  ${SYM_WARN} git not found (optional - git info won't display)"
    fi

    # Check bash version (needs bash 4+ for associative arrays)
    local bash_major="${BASH_VERSION%%.*}"
    if [ "$bash_major" -ge 4 ]; then
        echo -e "  ${SYM_OK} bash $BASH_VERSION"
    else
        echo -e "  ${SYM_WARN} bash $BASH_VERSION (version 4+ recommended)"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        return 1
    fi
    return 0
}

# Install missing dependencies
install_dependencies() {
    local os=$(detect_os)
    local pm=$(detect_package_manager)

    echo ""
    echo -e "${COLOR_BLUE}Installing missing dependencies...${NC}"
    echo -e "  OS: $os"
    echo -e "  Package manager: $pm"
    echo ""

    if [ "$pm" = "unknown" ]; then
        echo -e "${SYM_ERR} No supported package manager found."
        echo ""
        echo "Please install manually:"
        echo "  - jq: https://stedolan.github.io/jq/download/"
        echo "  - git: https://git-scm.com/downloads"
        return 1
    fi

    # Install jq if missing
    if ! command -v jq &>/dev/null; then
        install_package jq || return 1
    fi

    echo ""
    echo -e "${SYM_OK} Dependencies installed successfully!"
}

# Update settings.json
configure_settings() {
    echo ""
    echo -e "${COLOR_BLUE}Configuring Claude Code settings...${NC}"

    # Verify statusline script exists
    if [ ! -f "$STATUSLINE_SCRIPT" ]; then
        echo -e "${SYM_ERR} Statusline script not found: $STATUSLINE_SCRIPT"
        return 1
    fi

    # Make sure it's executable
    chmod +x "$STATUSLINE_SCRIPT"

    # Check for settings file
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo -e "${SYM_WARN} Settings file not found, creating: $SETTINGS_FILE"
        mkdir -p "$(dirname "$SETTINGS_FILE")"
        echo '{}' > "$SETTINGS_FILE"
    fi

    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        echo -e "${SYM_ERR} jq is required to update settings.json"
        echo ""
        echo "Manual setup: add to $SETTINGS_FILE:"
        local home_rel="${STATUSLINE_SCRIPT#"$HOME"/}"
        echo '  "statusLine": { "type": "command", "command": "bash -c '\''\"\\$HOME/'"$home_rel"'\"'\''" }'
        return 1
    fi

    # Build a portable $HOME-relative command for settings.json
    # This ensures the config works across machines with different usernames
    local home_relative="${STATUSLINE_SCRIPT#"$HOME"/}"
    local portable_cmd
    if [ "$home_relative" != "$STATUSLINE_SCRIPT" ]; then
        # Path is under $HOME - use portable bash -c wrapper with literal $HOME
        portable_cmd=$(printf 'bash -c '\''"%s/%s"'\''' '$HOME' "$home_relative")
    else
        # Path is outside $HOME - use absolute path as fallback
        portable_cmd="$STATUSLINE_SCRIPT"
    fi

    # Check if already configured with the correct path
    local current_cmd=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null)
    if [ "$current_cmd" = "$portable_cmd" ]; then
        echo -e "  ${SYM_OK} Statusline already configured correctly"
        return 0
    fi

    # Backup settings if modifying
    if [ -n "$current_cmd" ]; then
        local backup="${SETTINGS_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$SETTINGS_FILE" "$backup"
        echo -e "  ${SYM_OK} Backed up existing settings to: $backup"
    fi

    # Update settings.json - statusLine config + marketplace auto-update
    local updated
    updated=$(jq --arg cmd "$portable_cmd" '
        .statusLine = {"type": "command", "command": $cmd}
        | .extraKnownMarketplaces.ppplugins = {
            "source": {"source": "github", "repo": "privitera/ppplugins"},
            "autoUpdate": true
          }
    ' "$SETTINGS_FILE")

    echo "$updated" > "$SETTINGS_FILE"
    echo -e "  ${SYM_OK} Updated settings.json with statusLine configuration"
    echo -e "  ${SYM_OK} Enabled auto-update for ppplugins marketplace"
    echo -e "  ${COLOR_GREY}Command: $portable_cmd${NC}"
}

# Main
main() {
    echo ""
    echo -e "${COLOR_BLUE}=== Claude Code Statusline Setup ===${NC}"
    echo ""

    local os=$(detect_os)
    echo -e "${SYM_INFO} Detected OS: $os"
    echo ""

    # Check dependencies
    if ! check_dependencies; then
        if [ "$CHECK_ONLY" -eq 1 ]; then
            echo ""
            echo -e "${SYM_WARN} Missing dependencies detected. Run without --check-only to install."
            exit 1
        fi

        echo ""
        read -p "Install missing dependencies? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            install_dependencies || exit 1
        else
            echo -e "${SYM_WARN} Skipping dependency installation"
            echo "The statusline requires jq to function properly."
        fi
    fi

    if [ "$CHECK_ONLY" -eq 1 ]; then
        echo ""
        echo -e "${SYM_OK} All dependencies satisfied!"
        exit 0
    fi

    # Configure settings
    configure_settings || exit 1

    echo ""
    echo -e "${COLOR_GREEN}=== Setup Complete! ===${NC}"
    echo ""
    echo "Restart Claude Code to see the new status line."
    echo ""
    echo "Features:"
    echo "  - Context window progress bar with color-coded thresholds"
    echo "  - Token usage display: [used+free/total]"
    echo "  - Git branch and organization info"
    echo "  - Per-session caching for stable rendering"
    echo ""
    echo "Troubleshooting:"
    echo "  - Enable debug logging: set STATUSLINE_DEBUG=1 in settings.json env"
    echo "  - Debug logs: /tmp/statusline-debug.log"
    echo "  - Last JSON input: /tmp/statusline-last-input.json"
    echo ""
}

main "$@"
