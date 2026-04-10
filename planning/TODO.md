# ppplugins TODO

Author-facing task tracker for the ppplugins marketplace.

> This file is committed to GitHub but **not loaded by Claude Code**. Users who
> add the marketplace will see it in their local cache under
> `~/.claude/plugins/marketplaces/ppplugins/planning/` but it has no runtime
> effect — no slash commands, no skills, no scripts are registered from here.
> It exists purely for maintainer planning.

Task ID conventions:
- `SL-###` — statusline plugin
- `PPP-###` — marketplace-wide (README, CI, infra, cross-plugin)

## Current Sprint
(none)

## Backlog

### statusline

- [ ] **SL-001**: Add `/statusline` picker command with `AskUserQuestion` menu
  - **Why**: Single discoverable entrypoint for new users. One menu lists
    setup / uninstall / check-status / cancel, so users don't have to
    memorise sub-command names. Power users keep invoking
    `/statusline:setup` and `/statusline:uninstall` directly — this is a
    wrapper, not a replacement.
  - **Design**:
    - New file `statusline/commands/statusline.md` with frontmatter:
      ```
      allowed-tools: [
        "AskUserQuestion",
        "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh:*)",
        "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/uninstall.sh:*)",
        "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/status.sh:*)"
      ]
      ```
    - Body instructs Claude to call `AskUserQuestion` immediately with the
      four options, then branch to the matching script.
    - Branches call the existing `setup.sh` / `uninstall.sh` — no logic
      duplication.
    - Optional third option: new `scripts/status.sh` that prints the current
      `settings.json` statusline block via `jq` (read-only health check).
  - **Non-goals**:
    - Replacing `/statusline:setup` and `/statusline:uninstall` — they stay
      as canonical entrypoints for scripts, CI, docs, and muscle memory.
    - Interactive configuration of statusline options (bar width, colors,
      thresholds) — that's SL-002.
  - **Gotchas**:
    - `AskUserQuestion` **must** be in `allowed-tools` or users see a
      permission prompt before the picker renders, which defeats the point
      of "one-step discoverability."
    - Non-interactive invocations (`claude "/statusline"` in CI) will block
      waiting for input. Document that scripts should use the direct
      sub-commands, not the picker wrapper.
    - First-run UX for a brand-new user is slightly worse than
      `/statusline:setup` directly (extra click). Weigh against the
      discoverability gain before shipping.
  - **Acceptance**:
    - [ ] `/statusline` in a fresh project directory renders the picker
          immediately (no preamble from Claude).
    - [ ] Selecting **Setup** runs `setup.sh` and relays output verbatim.
    - [ ] Selecting **Uninstall** runs `uninstall.sh` and relays output.
    - [ ] Selecting **Check status** runs `status.sh` and shows the current
          settings block.
    - [ ] Selecting **Cancel** replies with a no-op confirmation and stops.
    - [ ] Existing `/statusline:setup` and `/statusline:uninstall` behaviour
          is unchanged (regression test via `--plugin-dir` dev mode).
  - **Size**: S — one new command file, optionally one small shell script.
  - **Context**: Designed in conversation on 2026-04-10 alongside the
    prompt-wording fix to `setup.md` / `uninstall.md` (ambiguous "Run this"
    phrasing). See commit history around that date for the sibling change.

## Completed
(none yet)
