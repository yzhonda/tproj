# agent-teams

Claude Code Agent Teams pane management for tproj.

## What's included

- **team-watcher** -- Hook-based daemon that manages Agent Teams pane lifecycle
- **reflow-agent-pane** -- Repositions agent panes when Claude Code spawns new splits
- **agent-monitor** -- Per-agent status display

## How it works

When Claude Code creates Agent Teams (teammates), it splits new tmux panes. team-watcher sets up a tmux `after-split-window` hook to intercept these splits and reposition them using reflow-agent-pane.

## Requirements

- Claude Code with Agent Teams support (`teammateMode: "tmux"` in settings)
- tmux (included with tproj core)
