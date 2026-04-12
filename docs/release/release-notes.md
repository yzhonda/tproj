## What's New

### Homebrew Distribution
```bash
brew tap usedhonda/tproj
brew install --cask tproj
```

### Setup Wizard
- `tproj init` — interactive setup: dependency check, workspace.yaml generation, Claude Code hooks configuration
- `tproj --check` — comprehensive health check with version info

### GUI Improvements
- Individual collapsible sections (Memory / CC & Codex)
- Window size persistence across restarts
- Diagonal resize blocked when snapped to Ghostty
- Functional bottom resize grip
- Removed Cmd+Q shortcut (prevents accidental quit)

### Persona System
- CC-specific feminine tone pool (丁寧, 感情的, 甘え, 気まぐれ, おっとり, 毒舌)
- New character types (お嬢様系, じゃじゃ馬系, 甘えん坊系, ヤンデレ系)
- Profession system for CC and Cdx (巫女, ナース, メイド, 歌姫, etc.)
- Expanded ERA pool with future variants (電脳都市, 蒸気未来, 深海都市, 軌道コロニー)

### Bug Fixes
- Fix pane background images not appearing for newly added projects
- Fix window size force-reverting on every SwiftUI redraw
