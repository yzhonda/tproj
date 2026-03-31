#!/bin/bash
set -euo pipefail

# tproj インストーラ
# 使い方: ./install.sh [-h] [-n] [-y]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ========== オプション ==========

DRY_RUN=false
AUTO_YES=false
CORE_ONLY=false
WITH_MEMORY=false
ALL_EXTENSIONS=false

usage() {
  cat << 'EOF'
tproj installer

Usage: ./install.sh [OPTIONS]

Options:
  -h, --help          Show this help
  -n, --dry-run       Show what would be done without making changes
  -y, --yes           Auto-yes (skip confirmations)
  --core-only         Install core only (no extensions)
  --with-memory       Include memory extension (cc-mem, memory-guard)
  --all               Install all extensions including memory

By default, messaging + persona + agent-teams extensions are installed.
Memory extension requires --with-memory or --all (runs a launchd daemon).

Examples:
  ./install.sh           # core + default extensions
  ./install.sh --all     # everything including memory
  ./install.sh --core-only  # minimal install
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -y|--yes)
      AUTO_YES=true
      shift
      ;;
    --core-only)
      CORE_ONLY=true
      shift
      ;;
    --with-memory)
      WITH_MEMORY=true
      shift
      ;;
    --all)
      ALL_EXTENSIONS=true
      WITH_MEMORY=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "   Help: ./install.sh -h"
      exit 1
      ;;
  esac
done

# ========== ヘルパー関数 ==========

# ドライラン対応のコマンド実行
run_cmd() {
  if $DRY_RUN; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

# Y/n 確認（-y で自動Yes）
confirm() {
  local prompt=$1
  if $AUTO_YES; then
    return 0
  fi
  echo -n "$prompt [Y/n] "
  read -r answer
  case "$answer" in
    [nN]|[nN][oO]) return 1 ;;
    *) return 0 ;;
  esac
}

check_command() {
  local cmd=$1
  local name=${2:-$cmd}
  if command -v "$cmd" &> /dev/null; then
    echo "  ✅ $name"
    return 0
  else
    echo "  ❌ $name"
    return 1
  fi
}

backup_if_exists() {
  local file=$1
  if [[ -f "$file" && ! -L "$file" ]]; then
    local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
    if $DRY_RUN; then
      echo "[DRY-RUN] 📋 バックアップ: $file -> $backup"
    else
      cp "$file" "$backup"
      echo "  📋 バックアップ: $backup"
    fi
  fi
}

# ========== 1. 依存関係チェック ==========

echo "🔍 依存関係を確認中..."

# brew でインストール可能なツール
BREW_DEPS=(npm:node git tmux yazi bat yq)
# npm でインストールするツール
NPM_DEPS=(claude:@anthropic-ai/claude-code codex:@openai/codex)

MISSING_BREW=()
MISSING_NPM=()

for dep in "${BREW_DEPS[@]}"; do
  cmd="${dep%%:*}"
  pkg="${dep##*:}"
  if ! check_command "$cmd"; then
    MISSING_BREW+=("$pkg")
  fi
done

for dep in "${NPM_DEPS[@]}"; do
  cmd="${dep%%:*}"
  pkg="${dep##*:}"
  name="$cmd"
  [[ "$cmd" == "claude" ]] && name="Claude Code"
  [[ "$cmd" == "codex" ]] && name="Codex"
  if ! check_command "$cmd" "$name"; then
    MISSING_NPM+=("$pkg")
  fi
done

# ========== 2. 不足ツールのインストール ==========

if [[ ${#MISSING_BREW[@]} -gt 0 ]]; then
  echo ""
  echo "❌ 以下のツールがありません: ${MISSING_BREW[*]}"

  if command -v brew &> /dev/null; then
    if confirm "🍺 brewでインストールしますか？"; then
      for pkg in "${MISSING_BREW[@]}"; do
        echo "📦 brew install $pkg"
        if ! $DRY_RUN; then
          brew install "$pkg"
        else
          echo "[DRY-RUN] brew install $pkg"
        fi
      done
    else
      echo ""
      echo "手動でインストールしてください:"
      for pkg in "${MISSING_BREW[@]}"; do
        echo "  brew install $pkg"
      done
      exit 1
    fi
  else
    echo ""
    echo "⚠️  Homebrewがインストールされていません"
    echo "   https://brew.sh を参照してインストール後、再実行してください"
    echo ""
    echo "   または手動でインストール:"
    for pkg in "${MISSING_BREW[@]}"; do
      echo "   • $pkg"
    done
    exit 1
  fi
fi

if [[ ${#MISSING_NPM[@]} -gt 0 ]]; then
  echo ""
  echo "❌ 以下のnpmパッケージがありません:"
  for pkg in "${MISSING_NPM[@]}"; do
    echo "   • $pkg"
  done

  if command -v npm &> /dev/null; then
    if confirm "📦 npmでグローバルインストールしますか？"; then
      for pkg in "${MISSING_NPM[@]}"; do
        echo "📦 npm install -g $pkg"
        if ! $DRY_RUN; then
          npm install -g "$pkg"
        else
          echo "[DRY-RUN] npm install -g $pkg"
        fi
      done
    else
      echo ""
      echo "手動でインストールしてください:"
      for pkg in "${MISSING_NPM[@]}"; do
        echo "  npm install -g $pkg"
      done
      exit 1
    fi
  else
    echo ""
    echo "⚠️  npmがありません。先にnpmをインストールしてください"
    exit 1
  fi
fi

echo ""
if $DRY_RUN; then
  echo "🔍 tproj インストール (ドライラン)"
else
  echo "🚀 tproj インストール開始"
fi

# ========== 3. Terminfo セットアップ ==========

if ! infocmp xterm-ghostty &>/dev/null; then
  if $DRY_RUN; then
    echo "[DRY-RUN] 📦 xterm-ghostty terminfo -> ~/.terminfo/"
  else
    echo "📦 xterm-ghostty terminfo -> ~/.terminfo/"
    tic -x "$SCRIPT_DIR/config/terminfo/xterm-ghostty.terminfo"
  fi
else
  echo "✅ xterm-ghostty terminfo (already installed)"
fi

# ========== 4. バックアップ & コピー ==========

# 4.1 tproj スクリプト
CORE_BINS=(tproj tproj-drop-column tproj-kill-pane tproj-toggle-yazi tproj-pane-focus-hook tproj-pane-clear-rank tproj-pane-watchdog tproj-respawn-guard tproj-postmortem tproj-mem-trace rebalance-workspace-columns sign-codex wait-for-pane-text)

if $DRY_RUN; then
  for bin_name in "${CORE_BINS[@]}"; do
    echo "[DRY-RUN] 📦 $bin_name -> ~/bin/"
  done
else
  echo "📦 Core scripts -> ~/bin/"
  mkdir -p ~/bin
  for bin_name in "${CORE_BINS[@]}"; do
    cp "$SCRIPT_DIR/bin/$bin_name" ~/bin/"$bin_name"
    chmod +x ~/bin/"$bin_name"
  done

  # Legacy cleanup: remove old launchd plist (renamed to com.tproj.memory-guard)
  OLD_PLIST="$HOME/Library/LaunchAgents/com.memory-guard.plist"
  # Always try bootout (plist may be loaded even if file was already deleted)
  launchctl bootout "gui/$(id -u)/com.memory-guard" 2>/dev/null || true
  if [[ -f "$OLD_PLIST" ]]; then
    rm -f "$OLD_PLIST"
    echo "  removed legacy $OLD_PLIST"
  fi

  # Legacy cleanup: remove stale binaries from previous installs
  for legacy_bin in tproj-gui tproj-mcp-init; do
    if [[ -f "$HOME/bin/$legacy_bin" ]]; then
      rm -f "$HOME/bin/$legacy_bin"
      echo "  removed legacy ~/bin/$legacy_bin"
    fi
  done
fi

# 4.2 tmux 設定
backup_if_exists ~/.tmux.conf
if $DRY_RUN; then
  echo "[DRY-RUN] 📦 tmux.conf -> ~/.tmux.conf"
else
  echo "📦 tmux.conf -> ~/.tmux.conf"
  cp "$SCRIPT_DIR/config/tmux/tmux.conf" ~/.tmux.conf
fi

# 4.3 yazi 設定
if $DRY_RUN; then
  echo "[DRY-RUN] 📦 yazi設定 -> ~/.config/yazi/"
else
  echo "📦 yazi設定 -> ~/.config/yazi/"
  mkdir -p ~/.config/yazi/plugins
fi
backup_if_exists ~/.config/yazi/yazi.toml
backup_if_exists ~/.config/yazi/keymap.toml
backup_if_exists ~/.config/yazi/package.toml
if ! $DRY_RUN; then
  cp "$SCRIPT_DIR/config/yazi/yazi.toml" ~/.config/yazi/
  cp "$SCRIPT_DIR/config/yazi/keymap.toml" ~/.config/yazi/
  cp "$SCRIPT_DIR/config/yazi/package.toml" ~/.config/yazi/
  cp -r "$SCRIPT_DIR/config/yazi/plugins/"* ~/.config/yazi/plugins/
fi

# 4.4 yaziパッケージ（piperプラグイン）
if command -v ya &> /dev/null; then
  if $DRY_RUN; then
    echo "[DRY-RUN] 📦 yazi plugins (ya pack)"
  else
    echo "📦 yazi plugins (ya pack)"
    if ! (cd ~/.config/yazi && ya pack -i 2>/dev/null); then
      echo "  ⚠️  yazi plugin install failed (best-effort)."
      echo "     Retry manually: cd ~/.config/yazi && ya pack -i"
    fi
  fi
fi

# ========== 5. PATH自動設定 ==========

if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
  echo ""
  echo "⚠️  ~/bin がPATHに含まれていません"

  SHELL_RC=""
  if [[ -f ~/.zshrc ]]; then
    SHELL_RC=~/.zshrc
  elif [[ -f ~/.bashrc ]]; then
    SHELL_RC=~/.bashrc
  fi

  if [[ -n "$SHELL_RC" ]]; then
    if confirm "📝 $SHELL_RC に PATH設定を追加しますか？"; then
      PATH_LINE='export PATH="$HOME/bin:$PATH"'
      if $DRY_RUN; then
        echo "[DRY-RUN] 以下を $SHELL_RC に追加:"
        echo "   $PATH_LINE"
      else
        echo "" >> "$SHELL_RC"
        echo "# Added by tproj installer" >> "$SHELL_RC"
        echo "$PATH_LINE" >> "$SHELL_RC"
        echo "✅ $SHELL_RC にPATH設定を追加しました"
        echo "   反映するには: source $SHELL_RC"
      fi
    else
      echo "   以下を手動で追加してください:"
      echo '   export PATH="$HOME/bin:$PATH"'
    fi
  else
    echo "   以下を ~/.zshrc または ~/.bashrc に追加してください:"
    echo '   export PATH="$HOME/bin:$PATH"'
  fi
fi

# ========== 6. Extensions ==========

if ! $CORE_ONLY; then
  echo ""
  echo "📦 Installing extensions..."
  mkdir -p ~/bin

  # --- messaging ---
  if [[ -d "$SCRIPT_DIR/extensions/messaging" ]]; then
    echo "  📦 messaging (tproj-msg)"
    if ! $DRY_RUN; then
      cp "$SCRIPT_DIR/extensions/messaging/tproj-msg" ~/bin/
      chmod +x ~/bin/tproj-msg
      # Install msg skill for Claude Code and Codex
      mkdir -p "$HOME/.claude/skills/msg" "$HOME/.codex/skills/msg"
      cp "$SCRIPT_DIR/extensions/messaging/skill-msg/SKILL.md" "$HOME/.claude/skills/msg/"
      cp "$SCRIPT_DIR/extensions/messaging/skill-msg/SKILL.md" "$HOME/.codex/skills/msg/"
    else
      echo "    [DRY-RUN] tproj-msg -> ~/bin/"
      echo "    [DRY-RUN] msg skill -> ~/.claude/skills/ + ~/.codex/skills/"
    fi
  fi

  # --- persona ---
  if [[ -d "$SCRIPT_DIR/extensions/persona" ]]; then
    echo "  📦 persona (cc-persona, tproj-pane-bg)"
    if ! $DRY_RUN; then
      cp "$SCRIPT_DIR/extensions/persona/cc-persona" ~/bin/
      cp "$SCRIPT_DIR/extensions/persona/tproj-pane-bg" ~/bin/
      chmod +x ~/bin/cc-persona ~/bin/tproj-pane-bg
    else
      echo "    [DRY-RUN] cc-persona, tproj-pane-bg -> ~/bin/"
    fi
    # Check optional deps
    if ! command -v jq &>/dev/null; then
      echo "    ⚠️  jq not found (required by cc-persona): brew install jq"
    fi
    if ! python3 -c "import genai" 2>/dev/null; then
      echo "    ℹ️  google-genai not found (optional, for AI image generation): pip3 install google-genai"
    fi
  fi

  # --- agent-teams ---
  if [[ -d "$SCRIPT_DIR/extensions/agent-teams" ]]; then
    echo "  📦 agent-teams (team-watcher, reflow-agent-pane, agent-monitor)"
    if ! $DRY_RUN; then
      for ext_bin in team-watcher reflow-agent-pane agent-monitor; do
        cp "$SCRIPT_DIR/extensions/agent-teams/$ext_bin" ~/bin/
        chmod +x ~/bin/"$ext_bin"
      done
    else
      echo "    [DRY-RUN] team-watcher, reflow-agent-pane, agent-monitor -> ~/bin/"
    fi
  fi

  # --- memory (opt-in) ---
  if $WITH_MEMORY && [[ -d "$SCRIPT_DIR/extensions/memory" ]]; then
    echo "  📦 memory (cc-mem, memory-guard, tproj-mem-json)"
    if ! $DRY_RUN; then
      cp "$SCRIPT_DIR/extensions/memory/cc-mem" ~/bin/
      cp "$SCRIPT_DIR/extensions/memory/memory-guard" ~/bin/
      cp "$SCRIPT_DIR/extensions/memory/tproj-mem-json" ~/bin/
      chmod +x ~/bin/cc-mem ~/bin/memory-guard ~/bin/tproj-mem-json

      # Install launchd plist for memory-guard
      if [[ -f "$SCRIPT_DIR/extensions/memory/launchd/com.tproj.memory-guard.plist.template" ]]; then
        PLIST_DIR="$HOME/Library/LaunchAgents"
        PLIST_FILE="$PLIST_DIR/com.tproj.memory-guard.plist"
        mkdir -p "$PLIST_DIR"
        sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/extensions/memory/launchd/com.tproj.memory-guard.plist.template" > "$PLIST_FILE"
        launchctl bootout "gui/$(id -u)/com.tproj.memory-guard" 2>/dev/null || true
        launchctl bootstrap "gui/$(id -u)" "$PLIST_FILE" 2>/dev/null || true
        echo "    ✅ memory-guard launchd daemon installed"
      fi
    else
      echo "    [DRY-RUN] cc-mem, memory-guard, tproj-mem-json -> ~/bin/"
      echo "    [DRY-RUN] memory-guard launchd plist -> ~/Library/LaunchAgents/"
    fi
  elif ! $WITH_MEMORY && [[ -d "$SCRIPT_DIR/extensions/memory" ]]; then
    echo "  ⏭️  memory (skipped, use --with-memory or --all to install)"
  fi
fi

# ========== 7. 完了メッセージ ==========

echo ""
if $DRY_RUN; then
  echo "✅ Dry run complete (no changes made)"
  echo ""
  echo "Run for real: ./install.sh"
else
  echo "✅ Installation complete!"
fi

echo ""
echo "Installed to:"
echo "   ~/bin/            core scripts"
echo "   ~/.tmux.conf      tmux configuration"
echo "   ~/.config/yazi/   yazi file manager"
if ! $CORE_ONLY; then
  echo "   ~/bin/            extensions (messaging, persona, agent-teams)"
  $WITH_MEMORY && echo "   ~/bin/            memory extension (cc-mem, memory-guard)"
fi
echo ""
echo "Usage:"
echo "   Single project: cd <project> && tproj"
echo "   Multi-project:  cp config/workspace.yaml.example ~/.config/tproj/workspace.yaml"
echo "                   # edit workspace.yaml, then run tproj"
if ! $CORE_ONLY; then
  echo ""
  echo "Optional environment variables (add to your shell profile):"
  echo '   export TPROJ_LABEL_HOOK=cc-persona          # persona labels on pane titles'
  echo '   export TPROJ_AFTER_LAYOUT_HOOK=tproj-pane-bg # AI-generated pane backgrounds'
fi
