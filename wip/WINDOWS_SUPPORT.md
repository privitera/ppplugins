# Windows / PowerShell Support (WIP)

Native PowerShell support for the statusline plugin is in progress.
Currently, Windows users should use WSL or Git Bash.

## Windows Requirements

### Windows (WSL)
```bash
# In WSL terminal
sudo apt install jq
```

### Windows (Git Bash)
1. Install [Git for Windows](https://git-scm.com/download/win) (includes Git Bash)
2. Download jq from [releases](https://github.com/stedolan/jq/releases) and add to PATH

## PowerShell Setup Script

`setup.ps1` handles dependency checking and settings configuration on Windows.
It still configures the bash-based `statusline-command.sh` to run via WSL/Git Bash.

A native PowerShell `statusline-command.ps1` is needed for full Windows support.

### Setup via PowerShell
```powershell
# Navigate to plugin directory
cd $env:USERPROFILE\.claude\plugins\marketplaces\ppplugins\statusline

# Run setup
.\scripts\setup.ps1
```
