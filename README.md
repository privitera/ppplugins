# ppplugins

Claude Code plugin marketplace by [1337_Pete](https://privitera.github.io/ppplugins/).

## Plugins

| Plugin | Description |
|--------|-------------|
| [statusline](./statusline/) | Custom status line with context window progress bar, token counts, and git info |

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- `jq` (installed automatically by the setup command, or `apt install jq` / `brew install jq`)
- `git` (optional, for branch/org display)

## Install

```bash
claude plugins marketplace add privitera/ppplugins && claude plugins install statusline@ppplugins
```

Then run `/statusline:setup` inside Claude Code to configure.

## Homepage

[privitera.github.io/ppplugins](https://privitera.github.io/ppplugins/)
