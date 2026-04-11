# tproj

A tmux-based workspace launcher for [Claude Code](https://github.com/anthropics/claude-code) and [Codex](https://github.com/openai/codex).

Spin up a structured terminal layout with Claude Code, Codex, and yazi side by side for any project.

## Features

- **Single-project mode** -- 3-pane layout: Claude Code + Codex + yazi
- **Multi-project mode** -- column-based workspace across multiple projects
- **Native macOS GUI** -- SwiftUI controller app with session management
- **Remote SSH** -- launch the same layout on a remote host
- **Workspace config** -- YAML-driven project management with aliases and per-project settings

## Requirements

- **macOS** (CLI core works on any tmux-capable OS; GUI app and memory extension are macOS-only)
- tmux, yazi, bat, yq, node/npm, git

```bash
brew install git tmux yazi bat yq node
npm install -g @anthropic-ai/claude-code @openai/codex
```

## Install

The installer copies scripts to `~/bin/` and overwrites the following config files (existing files are backed up automatically):

- `~/.tmux.conf`
- `~/.config/yazi/` (yazi.toml, keymap.toml, package.toml)
- Optionally appends a `PATH` entry to `~/.zshrc` or `~/.bashrc`

```bash
git clone https://github.com/usedhonda/tproj.git
cd tproj

# Preview what will be changed (no modifications)
./install.sh --dry-run

# Full install: core + default extensions
./install.sh

# Minimal install: core scripts only, no config overwrites
./install.sh --core-only

# Everything including memory watchdog daemon
./install.sh --all
```

Run `./install.sh -h` for all options.

## Usage

```bash
# Single-project mode (default)
cd /path/to/your/project
tproj

# Force single-project mode
tproj --single

# Remote host
tproj --remote <host>

# Graceful shutdown
tproj stop

# Force kill
tproj kill
```

## Multi-project workspace

Create a workspace config to manage multiple projects:

```bash
mkdir -p ~/.config/tproj
cp config/workspace.yaml.example ~/.config/tproj/workspace.yaml
```

Edit the file to list your projects, then run `tproj`:

```yaml
projects:
  - path: /Users/you/projects/frontend
    alias: fe

  - path: /Users/you/projects/backend
    alias: be

  - path: /Users/you/projects/infra
    alias: infra
    enabled: false   # available via --add but not started by default
```

In workspace mode, the GUI `Stop` action remembers the projects that were actually running by writing that set back into `projects[].enabled`. The next manual `Start` uses that saved subset.

### Workspace commands

```bash
tproj                 # start workspace (auto-detects workspace.yaml)
tproj --check         # show configured projects and status
tproj --add           # duplicate current column
tproj --add <alias>   # add a disabled project by alias
tproj --columns 3     # start only the first 3 projects
```

See `config/workspace.yaml.example` for the full field reference.

## GUI App (macOS)

A native SwiftUI app for session control and monitoring.

```bash
cd apps/tproj
./dev-app.sh           # debug build + launch
./dev-app.sh --release # release build (universal binary + app bundle)
```

The GUI auto-launches when `tproj` starts a session. Configure `gui.app_path` in `workspace.yaml` to pin a specific build.

## Extensions

tproj ships with optional extensions. All except memory are installed by default.

| Extension | What it does | Default | Side effects |
|-----------|-------------|---------|--------------|
| **messaging** | Inter-pane AI messaging (`tproj-msg`) | yes | Installs `msg` skill to `~/.claude/skills/` and `~/.codex/skills/` |
| **persona** | Deterministic AI persona generation + pane backgrounds | yes | Generates per-project config (`.persona.md`, `.codex/config.toml`, `.cc-status-bar.voice.json`) |
| **agent-teams** | Claude Code Agent Teams pane management | yes | Requires `teammateMode: "tmux"` in Claude Code settings |
| **memory** | Memory monitoring + watchdog daemon (macOS) | no | Installs a launchd daemon that monitors and can terminate processes |

```bash
./install.sh              # core + messaging + persona + agent-teams
./install.sh --all        # everything including memory
./install.sh --core-only  # minimal (no extensions)
```

See each extension's README under `extensions/` for details.

## Extension hooks

tproj supports hooks for customization:

| Environment variable | Purpose | Example |
|---------------------|---------|---------|
| `TPROJ_LABEL_HOOK` | Custom pane label generator | `export TPROJ_LABEL_HOOK=project-bootstrap` |
| `TPROJ_GUI_APP_PATH` | Override GUI app location | `export TPROJ_GUI_APP_PATH=~/Apps/tproj.app` |
| `TPROJ_AFTER_LAYOUT_HOOK` | Run after layout is set up | `export TPROJ_AFTER_LAYOUT_HOOK=tproj-pane-bg` |

### `TPROJ_LABEL_HOOK`

When set, tproj calls `$TPROJ_LABEL_HOOK --label <project_path> <cc|cdx>` to generate a suffix for pane titles. The primary tool is `project-bootstrap`; `cc-persona` remains as a compatibility alias. This lets you add persona labels, status indicators, or any custom text to your pane titles.

## Repository layout

```
bin/                            # core scripts
  tproj                         #   main launcher
  tproj-drop-column             #   batch column removal
  tproj-toggle-yazi             #   yazi pane toggle
  rebalance-workspace-columns   #   column width equalizer
  sign-codex                    #   macOS code signing for Codex
  wait-for-pane-text            #   wait for text in a tmux pane
config/                         # core configuration
  tmux/tmux.conf                #   tmux settings
  terminfo/                     #   terminal capability files
  yazi/                         #   yazi file manager config
  workspace.yaml.example        #   workspace template
apps/tproj/                     # SwiftUI GUI app source
extensions/                     # optional extensions
  messaging/                    #   tproj-msg + msg skill
  persona/                      #   project-bootstrap + cc-persona compat + tproj-pane-bg
  agent-teams/                  #   team-watcher, reflow-agent-pane, agent-monitor
  memory/                       #   cc-mem, memory-guard, tproj-mem-json
```

## Notes

- tproj does not run `npm update` automatically. Update manually when needed:
  ```bash
  npm update -g @anthropic-ai/claude-code @openai/codex
  ```
- For heavy multi-pane usage in Ghostty, consider lowering `scrollback-limit` (e.g. `3000`) to reduce memory pressure.

## License

MIT
