#!/usr/bin/env bash
set -euo pipefail
DEST="${HOME}/.agents/skills/overleaf-codex-workflow"
CLI="${HOME}/.local/bin/overleaf-codex"
rm -rf "$DEST"
if [[ -L "$CLI" ]]; then rm -f "$CLI"; fi
echo "Removed $DEST"
echo "Existing manuscript repositories and their AGENTS.md files were not modified."
