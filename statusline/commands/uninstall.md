---
description: "Remove statusline configuration from settings.json"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/uninstall.sh:*)"]
---

The uninstall script was executed by the harness before you received this prompt. Its output:

```!
${CLAUDE_PLUGIN_ROOT}/scripts/uninstall.sh
```

**Your task:**

1. Relay the output above to the user inside a fenced code block — verbatim, no summary, no interpretation.
2. **If the output reports a failure** (missing `jq`, permission errors on `~/.claude/settings.json`, invalid JSON, `${CLAUDE_PLUGIN_ROOT}` not resolving, etc.), help the user troubleshoot with specific, platform-aware fixes. Once they apply a fix, you may re-run `${CLAUDE_PLUGIN_ROOT}/scripts/uninstall.sh` to verify — the `allowed-tools` frontmatter permits it.
