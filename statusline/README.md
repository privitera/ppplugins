# Claude Code Statusline Plugin

A custom status line for Claude Code that displays context window usage, token counts, and git information in a colorful, informative bar.

```
user Opus 4.5 ████████████████████████████████████      49%      [73K+126K/200K] my-org/my-project:main
```

## Features

- **Context Window Progress Bar**: Visual representation of context usage with color-coded thresholds
  - Green (>30% free): Plenty of space
  - Orange (10-30% free): Getting low
  - Red (<10% free): Critical
- **Token Counts**: `[used+free/total]` breakdown in thousands
- **Git Integration**: Shows organization/project:branch
- **Per-Session Caching**: Prevents flashing during data gaps
- **Colorblind-Safe Palette**: Uses Wong/Tol recommended colors
- **Optimized Performance**: Single jq call, async I/O

## Requirements

### All Platforms
- **jq** (required): JSON processor for parsing Claude Code data
- **git** (optional): For displaying branch and organization info
- **bash 4+** (required): For the statusline script

### Platform-Specific

#### Linux
Most distributions include bash by default. Install jq:
```bash
# Debian/Ubuntu
sudo apt install jq

# Fedora/RHEL
sudo dnf install jq

# Arch
sudo pacman -S jq

# Alpine
sudo apk add jq
```

#### macOS
```bash
# Using Homebrew
brew install jq bash

# Note: macOS ships with bash 3.x, install bash 4+ via Homebrew
```

> **Windows:** Native PowerShell support is in progress. For now, use WSL or Git Bash. See `wip/WINDOWS_SUPPORT.md`.

## Installation

### Method 1: Using the Setup Command (Recommended)

After enabling the plugin, run in Claude Code:
```
/statusline:setup
```

This will:
1. Check for dependencies
2. Offer to install missing dependencies
3. Configure `~/.claude/settings.json` automatically

### Method 2: Using Setup Scripts Directly

#### Linux/macOS/WSL
```bash
# Navigate to plugin directory
cd ~/.claude/plugins/marketplaces/ppplugins/statusline

# Run setup
./scripts/setup.sh
```

### Method 3: Manual Configuration

Add to `~/.claude/settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "/path/to/statusline/scripts/statusline-command.sh"
  }
}
```

Replace `/path/to/statusline` with the actual path to the plugin.

## Uninstall

Run in Claude Code **before** removing the plugin:
```
/statusline:uninstall
```

This removes the `statusLine` entry from `~/.claude/settings.json`. Then finish with:
```bash
claude plugins uninstall statusline@ppplugins
```

## Configuration

### Feature Toggles

Edit `scripts/statusline-command.sh` to customize:

```bash
# Debug logging (outputs to /tmp/statusline-debug.log)
STATUSLINE_DEBUG=0    # Set via env var to enable

# Stale cache detection (shows grey bar if cache is old)
STALE_CHECK=0         # Set to 1 to enable
STALE_THRESHOLD=30    # Seconds before showing stale indicator
```

### Color Thresholds

The progress bar color changes based on free context percentage:
- **Green**: >30% free
- **Orange**: 10-30% free
- **Vermillion**: 5-10% free
- **Red**: <5% free

To modify thresholds, edit the `calc_colors()` function in `statusline-command.sh`.

### Bar Width

Default bar width is 50 characters. Modify `bar_width=50` in the script to adjust.

## Troubleshooting

### Status bar not appearing
1. Ensure jq is installed: `jq --version`
2. Check settings.json has correct path
3. Restart Claude Code

### Seeing flashing or grey bar
1. Enable debug logging: set `STATUSLINE_DEBUG=1` (see below)
2. Check `/tmp/statusline-debug.log` for `FALLBACK_VIEW` entries
3. This is normal on first launch; caching prevents subsequent flashes

### Git info not showing
1. Ensure git is installed: `git --version`
2. Verify you're in a git repository
3. Check the remote is GitHub (other hosts not supported for org extraction)

### Debug Logging

Enable detailed logging by adding to `~/.claude/settings.json`:
```json
{
  "env": {
    "STATUSLINE_DEBUG": "1"
  }
}
```

Debug files:
- `/tmp/statusline-debug.log` - Execution trace
- `/tmp/statusline-last-input.json` - Last JSON input from Claude Code

Log entry types:
- `INVOKE` - Script called
- `src=fresh/cache/stale/none` - Data source
- `fallbacks=model,org,branch` - Which values used cache
- `FALLBACK_VIEW` - Grey placeholder shown

### Cache Location

Per-session cache files are stored in:
```
scripts/.statusline-cache/<session-id>
```

Cache is automatically cleaned up after 1 hour of inactivity.

## How It Works

1. Claude Code invokes the script with JSON data on stdin
2. Single jq call extracts all needed values (optimized)
3. Script loads cache for session (prevents flash if data missing)
4. Computes progress bar, colors, and token counts
5. Git info fetched (or loaded from cache)
6. Cache updated asynchronously (fire-and-forget)
7. Output written to stdout

## Color Palette

Uses a colorblind-safe palette based on Wong (2011) and Paul Tol research:
- Blue: `#0072B2` - Used tokens
- Green: `#009E73` - Plenty of free space
- Orange: `#E69F00` - Getting low
- Vermillion: `#D55E00` - Low
- Red: `#CC3311` - Critical
- Grey: `#BBBBBB` - Neutral/stale

See `scripts/colors.sh` for full palette.

## License

MIT License - See LICENSE file for details.

## Contributing

Issues and pull requests welcome at the plugin repository.
