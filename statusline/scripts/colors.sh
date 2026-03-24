#!/bin/bash
# Colorblind-Safe Color Palette for Claude Code Statusline
# Based on Wong (2011) and Paul Tol recommendations
# See: https://personal.sron.nl/~pault/
#
# Uses 24-bit true color (works in most modern terminals)

# Primary palette - Wong/Tol hybrid
COLOR_BLUE='\033[38;2;0;114;178m'        # Primary blue
COLOR_ORANGE='\033[38;2;230;159;0m'      # Warning/attention
COLOR_GREEN='\033[38;2;0;158;115m'       # Success (bluish-green)
COLOR_GREY='\033[38;2;187;187;187m'      # Neutral/muted
COLOR_PURPLE='\033[38;2;204;121;167m'    # Accent
COLOR_CYAN='\033[38;2;51;187;238m'       # Info/secondary
COLOR_DARK_PURPLE='\033[38;2;170;51;119m' # Deep accent
COLOR_MAGENTA='\033[38;2;238;51;119m'    # Highlight
COLOR_VERMILLION='\033[38;2;213;94;0m'   # Error/danger (reddish-orange)
COLOR_RED='\033[38;2;204;51;17m'         # Critical error
COLOR_YELLOW='\033[38;2;204;187;68m'     # Highlight/warning

# Reset
NC='\033[0m'

# Export all colors for subshells
export COLOR_BLUE COLOR_ORANGE COLOR_GREEN COLOR_GREY COLOR_PURPLE
export COLOR_CYAN COLOR_DARK_PURPLE COLOR_MAGENTA COLOR_VERMILLION
export COLOR_RED COLOR_YELLOW NC
