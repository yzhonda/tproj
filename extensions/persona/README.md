# persona

Deterministic AI persona generation and pane background images.

## What's included

- **cc-persona** -- Assigns unique, reproducible personas to CC and Cdx based on project path
- **tproj-pane-bg** -- Generates AI artwork for tmux pane backgrounds using Gemini

## How it works

Each project gets a deterministic persona derived from an MD5 hash of its path. Traits include MBTI type, gender, age, historical era, speaking tone, character archetype, and relationship style.

cc-persona runs automatically on Claude Code session start (via SessionStart hook) and generates:

- `MEMORY.md` persona section (for Claude Code)
- `.codex/config.toml` (for Codex)
- `.cc-status-bar.voice.json` (for VOICEVOX TTS, optional)

## Pane backgrounds

tproj-pane-bg generates character artwork using Google's Gemini image models, driven by the persona traits. Images are cached per-project in `.local/tproj-pane-bg/`.

## Requirements

- `jq` (required by cc-persona)
- `python3` + `google-genai` (optional, for image generation)
- `GEMINI_API_KEY` in `~/.env` (optional, for image generation)
- VOICEVOX (optional, for TTS voice synthesis via cc-status-bar)
