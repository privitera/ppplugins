# Claude Code Statusline - Windows Setup Script
# Installs dependencies and configures settings.json
#
# Usage: .\setup.ps1 [-CheckOnly]
#   -CheckOnly  Only check dependencies, don't install or configure
#
# Requirements:
#   - Windows 10/11 with PowerShell 5.1+
#   - Chocolatey or winget for package installation
#   - Note: The statusline script itself requires bash (Git Bash or WSL)

param(
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-ColorOutput {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Write-Ok { param([string]$Text) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $Text }
function Write-Warn { param([string]$Text) Write-Host "[!] " -ForegroundColor Yellow -NoNewline; Write-Host $Text }
function Write-Err { param([string]$Text) Write-Host "[X] " -ForegroundColor Red -NoNewline; Write-Host $Text }
function Write-Info { param([string]$Text) Write-Host "[i] " -ForegroundColor Cyan -NoNewline; Write-Host $Text }

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginRoot = Split-Path -Parent $ScriptDir
$StatuslineScript = Join-Path $ScriptDir "statusline-command.sh"
$SettingsFile = Join-Path $env:USERPROFILE ".claude\settings.json"

# Detect package manager
function Get-PackageManager {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        return "winget"
    }
    elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        return "choco"
    }
    else {
        return "none"
    }
}

# Check if running in WSL or Git Bash
function Test-BashEnvironment {
    # Check for Git Bash
    $gitBash = Join-Path $env:ProgramFiles "Git\bin\bash.exe"
    if (Test-Path $gitBash) {
        return @{ Available = $true; Path = $gitBash; Type = "GitBash" }
    }

    # Check for WSL
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        return @{ Available = $true; Path = "wsl"; Type = "WSL" }
    }

    return @{ Available = $false; Path = ""; Type = "None" }
}

# Install package
function Install-Dependency {
    param([string]$Package, [string]$WingetId, [string]$ChocoName)

    $pm = Get-PackageManager

    Write-Info "Installing $Package using $pm..."

    switch ($pm) {
        "winget" {
            winget install --id $WingetId --accept-package-agreements --accept-source-agreements
        }
        "choco" {
            choco install $ChocoName -y
        }
        default {
            Write-Err "No package manager found. Please install $Package manually."
            return $false
        }
    }

    return $true
}

# Check dependencies
function Test-Dependencies {
    Write-ColorOutput "`nChecking dependencies..." -Color Cyan

    $allGood = $true

    # Check for bash environment
    $bash = Test-BashEnvironment
    if ($bash.Available) {
        Write-Ok "Bash environment: $($bash.Type) at $($bash.Path)"
    }
    else {
        Write-Warn "No bash environment found (Git Bash or WSL required)"
        $allGood = $false
    }

    # Check jq (in bash environment)
    if ($bash.Available) {
        $jqCheck = $null
        if ($bash.Type -eq "WSL") {
            $jqCheck = wsl which jq 2>$null
        }
        elseif ($bash.Type -eq "GitBash") {
            $jqCheck = & $bash.Path -c "which jq" 2>$null
        }

        if ($jqCheck) {
            Write-Ok "jq installed in $($bash.Type)"
        }
        else {
            Write-Warn "jq not found in $($bash.Type) (required)"
            $allGood = $false
        }
    }

    # Check git
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitVersion = git --version
        Write-Ok "git: $gitVersion"
    }
    else {
        Write-Warn "git not found (optional - git info won't display)"
    }

    return $allGood
}

# Configure settings.json
function Set-ClaudeSettings {
    Write-ColorOutput "`nConfiguring Claude Code settings..." -Color Cyan

    # Check statusline script exists
    if (-not (Test-Path $StatuslineScript)) {
        Write-Err "Statusline script not found: $StatuslineScript"
        return $false
    }

    # Ensure .claude directory exists
    $claudeDir = Split-Path -Parent $SettingsFile
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Write-Ok "Created .claude directory"
    }

    # Create settings.json if it doesn't exist
    if (-not (Test-Path $SettingsFile)) {
        '{}' | Out-File -FilePath $SettingsFile -Encoding utf8
        Write-Ok "Created settings.json"
    }

    # Read current settings
    $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json

    # Build a portable $HOME-relative command
    # Convert absolute path to $HOME-relative so it works across machines
    $bash = Test-BashEnvironment
    $bashPath = $StatuslineScript

    if ($bash.Type -eq "WSL") {
        # Convert Windows path to WSL path
        $bashPath = wsl wslpath -u "$StatuslineScript"
        # Make it $HOME-relative
        $wslHome = wsl bash -c 'echo $HOME'
        if ($bashPath.StartsWith($wslHome)) {
            $homeRelative = $bashPath.Substring($wslHome.Length + 1)
            $bashPath = "bash -c '`"`$HOME/$homeRelative`"'"
        }
    }
    elseif ($bash.Type -eq "GitBash") {
        # Convert to Unix-style path for Git Bash
        $bashPath = $StatuslineScript -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
        # Make it $HOME-relative (Git Bash $HOME is typically /c/Users/username)
        $gitBashHome = & $bash.Path -c 'echo $HOME' 2>$null
        if ($gitBashHome -and $bashPath.StartsWith($gitBashHome)) {
            $homeRelative = $bashPath.Substring($gitBashHome.Length + 1)
            $bashPath = "bash -c '`"`$HOME/$homeRelative`"'"
        }
    }

    # Check if already configured
    $currentCmd = $settings.statusLine.command
    if ($currentCmd -and $currentCmd -like "*statusline-command.sh*" -and ($currentCmd -like '*$HOME*' -or $currentCmd -like "*$env:USERPROFILE*")) {
        Write-Ok "Statusline already configured correctly"
        return $true
    }

    # Backup existing settings
    if ($currentCmd) {
        $backup = "$SettingsFile.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $SettingsFile $backup
        Write-Ok "Backed up existing settings to: $backup"
    }

    # Update settings
    $settings | Add-Member -NotePropertyName "statusLine" -NotePropertyValue @{
        type = "command"
        command = $bashPath
    } -Force

    $settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $SettingsFile -Encoding utf8
    Write-Ok "Updated settings.json with statusLine configuration"
    Write-Host "   Command: $bashPath" -ForegroundColor Gray

    return $true
}

# Main
function Main {
    Write-ColorOutput "`n=== Claude Code Statusline Setup (Windows) ===" -Color Cyan
    Write-Host ""

    Write-Info "Platform: Windows"
    Write-Info "Package manager: $(Get-PackageManager)"
    Write-Host ""

    # Check dependencies
    $depsOk = Test-Dependencies

    if (-not $depsOk) {
        if ($CheckOnly) {
            Write-Host ""
            Write-Warn "Missing dependencies detected."
            Write-Host ""
            Write-Host "To install dependencies:"
            Write-Host "  1. Install Git for Windows (includes Git Bash): https://git-scm.com/download/win"
            Write-Host "  2. Or enable WSL: wsl --install"
            Write-Host "  3. Install jq in your bash environment:"
            Write-Host "     - WSL: sudo apt install jq"
            Write-Host "     - Git Bash: download from https://stedolan.github.io/jq/"
            exit 1
        }

        Write-Host ""
        Write-Warn "The statusline requires a bash environment (Git Bash or WSL) and jq."
        Write-Host ""
        Write-Host "Recommended setup:"
        Write-Host "  1. Install Git for Windows: https://git-scm.com/download/win"
        Write-Host "  2. Open Git Bash and run: curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe -o /usr/bin/jq.exe"
        Write-Host ""
        Write-Host "Or use WSL:"
        Write-Host "  1. wsl --install"
        Write-Host "  2. sudo apt install jq"
        Write-Host ""

        $continue = Read-Host "Continue with settings configuration anyway? [y/N]"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            exit 1
        }
    }

    if ($CheckOnly) {
        Write-Host ""
        Write-Ok "All dependencies satisfied!"
        exit 0
    }

    # Configure settings
    if (-not (Set-ClaudeSettings)) {
        exit 1
    }

    Write-Host ""
    Write-ColorOutput "=== Setup Complete! ===" -Color Green
    Write-Host ""
    Write-Host "Restart Claude Code to see the new status line."
    Write-Host ""
    Write-Host "Note: The statusline script runs in bash. Make sure you have:"
    Write-Host "  - Git Bash (from Git for Windows), or"
    Write-Host "  - WSL with Ubuntu/Debian"
    Write-Host ""
    Write-Host "Troubleshooting:"
    Write-Host "  - Enable debug logging: set STATUSLINE_DEBUG=1 in settings.json env"
    Write-Host "  - Debug logs: /tmp/statusline-debug.log (in your bash environment)"
    Write-Host ""
}

Main
