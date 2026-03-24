#!/bin/bash
# Claude Code Status Line - Custom progress bar with context window visualization
# Format: user model ████████ XX% ▓▓▓▓▓▓▓▓ [tokens] repo:branch
#
# Features:
# - Real-time context window usage bar with color-coded thresholds
# - Per-session caching to prevent flashing during data gaps
# - Single jq call for optimal performance
# - Async I/O for cache and debug writes
# - Git branch and organization display
#
# Dependencies: jq, git (optional)
# Installation: Run /statusline:setup or see README.md

# Read JSON input from stdin
input=$(cat)

# Determine script location for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Extract ALL values from JSON in a single jq call (performance optimization)
# Include a flag to detect if current_usage is null vs legitimately zero
eval "$(echo "$input" | jq -r '
  @sh "cwd=\(.workspace.current_dir // "")",
  @sh "project_dir=\(.workspace.project_dir // "")",
  @sh "model=\(.model.display_name // "")",
  @sh "session_id=\(.session_id // "")",
  @sh "ctx_size=\(.context_window.context_window_size // 0)",
  @sh "input_tokens=\(.context_window.current_usage.input_tokens // 0)",
  @sh "cache_create=\(.context_window.current_usage.cache_creation_input_tokens // 0)",
  @sh "cache_read=\(.context_window.current_usage.cache_read_input_tokens // 0)",
  @sh "usage_is_null=\(if .context_window.current_usage == null then "1" else "0" end)"
')"

# Source colors or use fallback
if [ -f "$SCRIPT_DIR/colors.sh" ]; then
    source "$SCRIPT_DIR/colors.sh"
else
    # Colorblind-safe palette (Wong/Tol hybrid)
    COLOR_BLUE='\033[38;2;0;114;178m'
    COLOR_ORANGE='\033[38;2;230;159;0m'
    COLOR_GREEN='\033[38;2;0;158;115m'
    COLOR_GREY='\033[38;2;187;187;187m'
    COLOR_PURPLE='\033[38;2;204;121;167m'
    COLOR_CYAN='\033[38;2;51;187;238m'
    COLOR_DARK_PURPLE='\033[38;2;170;51;119m'
    COLOR_MAGENTA='\033[38;2;238;51;119m'
    COLOR_VERMILLION='\033[38;2;213;94;0m'
    COLOR_RED='\033[38;2;204;51;17m'
    NC='\033[0m'
fi

# Fixed bar width (50 chars = 1:2 ratio, 1% = 0.5 char)
bar_width=50

# Background colors for percentage pill
BG_CYAN='\033[48;2;51;187;238m'
BG_GREEN='\033[48;2;0;158;115m'
BG_ORANGE='\033[48;2;230;159;0m'
BG_VERMILLION='\033[48;2;213;94;0m'
BG_RED='\033[48;2;204;51;17m'
FG_BLACK='\033[38;2;0;0;0m'
FG_WHITE='\033[38;2;255;255;255m'

# Cache directory for last known values (one file per session, prevents flash)
# Use /tmp for cache to ensure write permissions (survives across sessions within same day)
CACHE_DIR="/tmp/.statusline-cache-$(whoami)"
if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
    # Fallback to user home if /tmp fails (shouldn't happen)
    CACHE_DIR="$HOME/.cache/statusline"
    mkdir -p "$CACHE_DIR" 2>/dev/null || CACHE_DIR=""
fi

# Feature toggles
DEBUG_LOG="${STATUSLINE_DEBUG:-0}"   # Set STATUSLINE_DEBUG=1 env var to enable debug logging
STALE_CHECK=0         # Set to 1 to enable stale detection (grey bar after threshold)
STALE_THRESHOLD=30    # seconds before cache is considered stale (if STALE_CHECK=1)

# Debug files (only used when DEBUG_LOG=1)
DEBUG_FILE="/tmp/statusline-debug.log"
DEBUG_JSON="/tmp/statusline-last-input.json"

# Save raw JSON input for debugging (async - fire and forget)
if [ "$DEBUG_LOG" -eq 1 ]; then
    {
        echo "$input" > "$DEBUG_JSON"
        ts=$(date '+%H:%M:%S.%3N')
        echo "$ts session=${session_id:0:8} INVOKE model=${model:-null}" >> "$DEBUG_FILE"
    } &
fi

# Session-specific cache file
if [ -n "$session_id" ] && [ -n "$CACHE_DIR" ]; then
    CACHE_FILE="$CACHE_DIR/$session_id"
else
    # Fallback for missing session_id or cache dir (shouldn't happen)
    CACHE_FILE=""
fi

# Periodic cleanup: remove cache files older than 1 hour (run ~1% of the time)
if [ -n "$CACHE_DIR" ] && [ $((RANDOM % 100)) -eq 0 ]; then
    find "$CACHE_DIR" -type f -mmin +60 -delete 2>/dev/null &
fi

# Dimmed grey background for stale state
BG_GREY='\033[48;2;68;68;68m'

# Calculate colors based on free percentage and stale state
# Sets: free_fg, free_bg, pct_fg, used_bg
calc_colors() {
    local free_pct=$1
    local stale=$2

    if [ "$stale" -eq 1 ]; then
        used_bg="${BG_GREY}"
        free_bg="${BG_GREY}"
        free_fg="${COLOR_GREY}"
        pct_fg="${COLOR_GREY}"
    else
        used_bg="${BG_CYAN}"
        if [ "$free_pct" -gt 30 ]; then
            free_fg="${COLOR_GREEN}"
            free_bg="${BG_GREEN}"
            pct_fg="${FG_WHITE}"
        elif [ "$free_pct" -gt 10 ]; then
            free_fg="${COLOR_ORANGE}"
            free_bg="${BG_ORANGE}"
            pct_fg="${FG_BLACK}"
        elif [ "$free_pct" -gt 5 ]; then
            free_fg="${COLOR_VERMILLION}"
            free_bg="${BG_VERMILLION}"
            pct_fg="${FG_WHITE}"
        else
            free_fg="${COLOR_RED}"
            free_bg="${BG_RED}"
            pct_fg="${FG_WHITE}"
        fi
    fi
}

# Render progress bar
# Uses globals: used_bg, free_bg, pct_fg, free_fg, bar_width, NC
render_bar() {
    local curr=$1
    local sz=$2

    local used_pct=$((curr * 100 / sz))
    local free_pct=$((100 - used_pct))
    [ "$free_pct" -lt 0 ] && free_pct=0

    local used_chars=$((used_pct * bar_width / 100))
    [ "$used_chars" -lt 4 ] && used_chars=4

    local free_total=$((bar_width - used_chars))
    [ "$free_total" -lt 0 ] && free_total=0

    local pct_text
    pct_text=$(printf "%d%%" "$free_pct")
    local pct_len=${#pct_text}

    local bar=""
    if [ "$free_total" -ge 4 ]; then
        local left_pad=$(( (free_total - pct_len) / 2 ))
        local right_pad=$((free_total - pct_len - left_pad))
        [ "$left_pad" -lt 0 ] && left_pad=0
        [ "$right_pad" -lt 0 ] && right_pad=0

        bar="${used_bg}"
        for ((i=0; i<used_chars; i++)); do bar+=" "; done
        bar+="${NC}${free_bg}${pct_fg}"
        for ((i=0; i<left_pad; i++)); do bar+=" "; done
        bar+="${pct_text}"
        for ((i=0; i<right_pad; i++)); do bar+=" "; done
        bar+="${NC}"
    else
        local text_with_pad=" ${pct_text}"
        local text_len=${#text_with_pad}
        local used_blocks=$((used_chars - text_len - 1))
        [ "$used_blocks" -lt 0 ] && used_blocks=0

        bar="${used_bg}"
        for ((i=0; i<used_blocks; i++)); do bar+=" "; done
        bar+="${free_fg}${text_with_pad} ${NC}"
        bar+="${free_bg}"
        for ((i=0; i<free_total; i++)); do bar+=" "; done
        bar+="${NC}"
    fi

    echo "$bar"
}

# Render tokens info
# Uses globals: free_fg, COLOR_GREY, COLOR_CYAN, COLOR_MAGENTA, NC
render_tokens() {
    local curr=$1
    local sz=$2

    local used_k=$((curr / 1000))
    local free_k=$(( (sz - curr) / 1000 ))
    local total_k=$((sz / 1000))
    echo "${COLOR_GREY}[${COLOR_CYAN}${used_k}K${COLOR_GREY}+${free_fg}${free_k}K${COLOR_GREY}/${COLOR_MAGENTA}${total_k}K${COLOR_GREY}]${NC}"
}

# === Load cache first (baseline for stable rendering) ===
cached_current=""
cached_size=""
cached_timestamp=0
cached_model=""
cached_git_org=""
cached_project=""
cached_branch=""
if [ -n "$CACHE_FILE" ] && [ -f "$CACHE_FILE" ]; then
    source "$CACHE_FILE" 2>/dev/null
    cached_current="$current"
    cached_size="$size"
    cached_timestamp="${timestamp:-0}"
    cached_model="${c_model:-}"
    cached_git_org="${c_git_org:-}"
    cached_project="${c_project:-}"
    cached_branch="${c_branch:-}"
fi

# === Parse fresh data from input (already extracted via single jq call) ===
fresh_current=""
fresh_size=""

# Calculate total tokens from already-extracted values
# CRITICAL: Only accept fresh data if current_usage is NOT null
# When current_usage is null, Claude Code hasn't loaded token data yet (rapid successive calls)
if [ "$ctx_size" -gt 0 ] 2>/dev/null && [ "$usage_is_null" != "1" ]; then
    fresh_current=$((input_tokens + cache_create + cache_read))
    fresh_size="$ctx_size"
fi

# === Determine which values to use and update cache ===
now=$(date +%s)
is_stale=0
data_source=""

if [ -n "$fresh_current" ] && [ -n "$fresh_size" ]; then
    # Fresh data available - use it (cache written later with all values)
    current="$fresh_current"
    size="$fresh_size"
    data_source="fresh"
elif [ -n "$cached_current" ] && [ -n "$cached_size" ]; then
    # No fresh data - use cache
    current="$cached_current"
    size="$cached_size"
    age=$((now - cached_timestamp))
    # Check staleness (only if enabled)
    if [ "$STALE_CHECK" -eq 1 ] && [ "$age" -gt "$STALE_THRESHOLD" ]; then
        is_stale=1
        data_source="stale(${age}s)"
    else
        data_source="cache(${age}s)"
    fi
else
    # No data at all
    current=""
    size=""
    data_source="none"
fi

# Debug logging (async) - enhanced to show null usage detection
if [ "$DEBUG_LOG" -eq 1 ]; then
    {
        ts=$(date '+%H:%M:%S.%3N')
        # Detect null usage object from JSON
        null_usage=""
        if echo "$input" | jq -e '.context_window.current_usage == null' > /dev/null 2>&1; then
            null_usage=" NULL_USAGE"
        fi
        echo "$ts session=${session_id:0:8} src=$data_source stale=$is_stale fresh_cur=$fresh_current cached_cur=$cached_current ctx_sz=$ctx_size in_tok=$input_tokens${null_usage}" >> "$DEBUG_FILE"
    } &
fi

# === Render bar ===
progress_bar=""
tokens_info=""

if [ -n "$current" ] && [ -n "$size" ] && [ "$size" -gt 0 ]; then
    # Calculate free_pct and colors in main shell (not subshell)
    free_pct=$((100 - (current * 100 / size)))
    [ "$free_pct" -lt 0 ] && free_pct=0
    calc_colors "$free_pct" "$is_stale"

    # Now render using the global color variables
    progress_bar=$(render_bar "$current" "$size")
    tokens_info=$(render_tokens "$current" "$size")
fi

# === Final fallback: no data, no cache ===
if [ -z "$progress_bar" ]; then
    # Log fallback view (async - this should be rare, only new sessions)
    if [ "$DEBUG_LOG" -eq 1 ]; then
        {
            ts=$(date '+%H:%M:%S.%3N')
            echo "$ts session=${session_id:0:8} FALLBACK_VIEW no_cache=true" >> "$DEBUG_FILE"
        } &
    fi

    # All grey bar with "..." to indicate no data
    progress_bar="${BG_GREY}${COLOR_GREY}"
    left_pad=$(( (bar_width - 3) / 2 ))
    right_pad=$((bar_width - 3 - left_pad))
    for ((i=0; i<left_pad; i++)); do progress_bar+=" "; done
    progress_bar+="..."
    for ((i=0; i<right_pad; i++)); do progress_bar+=" "; done
    progress_bar+="${NC}"

    tokens_info="${COLOR_GREY}[---K+---K/---K]${NC}"
fi

# Git info - try fresh, fallback to cache
git_org=""
project=""
branch=""

if [ -n "$project_dir" ] && [ "$project_dir" != "null" ]; then
    project=$(basename "$project_dir")

    if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
        branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
        git_org=$(git -C "$cwd" remote -v 2>/dev/null | head -1 | sed -n 's#.*github.com[:/]\([^/]*\)/.*#\1#p')
    fi
fi

# Use cached values if fresh not available (track fallbacks for telemetry)
fallbacks=""
if [ -z "$model" ] || [ "$model" = "null" ]; then
    model="$cached_model"
    [ -n "$cached_model" ] && fallbacks="${fallbacks}model,"
fi
if [ -z "$git_org" ]; then
    git_org="$cached_git_org"
    [ -n "$cached_git_org" ] && fallbacks="${fallbacks}org,"
fi
if [ -z "$project" ]; then
    project="$cached_project"
    [ -n "$cached_project" ] && fallbacks="${fallbacks}project,"
fi
if [ -z "$branch" ]; then
    branch="$cached_branch"
    [ -n "$cached_branch" ] && fallbacks="${fallbacks}branch,"
fi

# Log fallbacks (async)
if [ "$DEBUG_LOG" -eq 1 ] && [ -n "$fallbacks" ]; then
    {
        ts=$(date '+%H:%M:%S.%3N')
        echo "$ts session=${session_id:0:8} fallbacks=${fallbacks%,}" >> "$DEBUG_FILE"
    } &
fi

# Update cache with all values (atomic write to prevent race conditions)
# ONLY write cache if we have fresh token data - never cache empty/null data
if [ -n "$CACHE_FILE" ] && [ -n "$fresh_current" ] && [ -n "$fresh_size" ]; then
    {
        # Use atomic write: temp file -> rename
        CACHE_TMP="${CACHE_FILE}.tmp.$$"
        {
            echo "current=$current"
            echo "size=$size"
            echo "timestamp=$now"
            echo "c_model=$model"
            echo "c_git_org=$git_org"
            echo "c_project=$project"
            echo "c_branch=$branch"
        } > "$CACHE_TMP"
        mv "$CACHE_TMP" "$CACHE_FILE" 2>/dev/null
    } &
fi

# Render project_branch
project_branch=""
if [ -n "$project" ]; then
    if [ -n "$branch" ]; then
        if [ -n "$git_org" ]; then
            project_branch="${COLOR_DARK_PURPLE}${git_org}${COLOR_GREY}/${COLOR_BLUE}${project}${COLOR_GREY}:${COLOR_ORANGE}${branch}${NC}"
        else
            project_branch="${COLOR_BLUE}${project}${COLOR_GREY}:${COLOR_ORANGE}${branch}${NC}"
        fi
    else
        project_branch="${COLOR_BLUE}${project}${NC}"
    fi
fi

# === OUTPUT ===

# Single line: user model bar [tokens] repo:branch
printf '%b' "${COLOR_DARK_PURPLE}$(whoami)${NC} ${COLOR_GREEN}${model}${NC} ${progress_bar} ${tokens_info} ${project_branch}"
