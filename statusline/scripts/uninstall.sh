#!/bin/bash
# Claude Code Statusline - Uninstall Script
# Removes statusline configuration from settings.json
#
# Usage: ./uninstall.sh
#
# Run this BEFORE uninstalling the plugin:
#   /statusline:uninstall
#   claude plugins uninstall statusline@ppplugins

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

SYM_OK="${COLOR_GREEN}[OK]${NC}"
SYM_WARN="${COLOR_ORANGE}[!]${NC}"
SYM_ERR="${COLOR_RED}[X]${NC}"
SYM_INFO="${COLOR_BLUE}[i]${NC}"

SETTINGS_FILE="$HOME/.claude/settings.json"

echo ""
echo -e "${COLOR_BLUE}=== Claude Code Statusline Uninstall ===${NC}"
echo ""

if [ ! -f "$SETTINGS_FILE" ]; then
    echo -e "${SYM_WARN} Settings file not found: $SETTINGS_FILE"
    echo "Nothing to clean up."
    exit 0
fi

if ! command -v jq &>/dev/null; then
    echo -e "${SYM_ERR} jq is required to update settings.json"
    echo ""
    echo "Manual cleanup: remove the \"statusLine\" key from $SETTINGS_FILE"
    exit 1
fi

# Check if statusLine exists
has_statusline=$(jq 'has("statusLine")' "$SETTINGS_FILE" 2>/dev/null)

if [ "$has_statusline" != "true" ]; then
    echo -e "${SYM_OK} No statusline configuration found. Already clean."
    exit 0
fi

# Backup before modifying
backup="${SETTINGS_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS_FILE" "$backup"
echo -e "${SYM_OK} Backed up settings to: $backup"

# Remove statusLine entry
updated=$(jq 'del(.statusLine)' "$SETTINGS_FILE")
echo "$updated" > "$SETTINGS_FILE"
echo -e "${SYM_OK} Removed statusLine configuration"

echo ""
echo -e "${COLOR_GREEN}=== Uninstall Complete ===${NC}"
echo ""
echo "To finish removing the plugin, run:"
echo "  claude plugins uninstall statusline@ppplugins"
echo ""
echo "Restart Claude Code for changes to take effect."
echo ""
