#!/usr/bin/env bash
set -euo pipefail
DEST_BASE=""
case "${1:-}" in
  "")
    [[ $# -eq 0 ]] || exit 2
    [[ -n "${HOME:-}" ]] || { echo 'User uninstall requires HOME to be set.' >&2; exit 1; }
    DEST_BASE="${HOME}/.agents/skills"
    ;;
  --repo)
    [[ $# -eq 2 ]] || { echo 'Usage: ./uninstall.sh [--repo /path/repo]' >&2; exit 2; }
    DEST_BASE="$(cd "$2" && pwd)/.agents/skills"
    ;;
  *) echo 'Usage: ./uninstall.sh [--repo /path/repo]' >&2; exit 2 ;;
esac
DEST="$DEST_BASE/overleaf-codex-workflow"
CLI=""
if [[ -n "${HOME:-}" ]]; then CLI="${HOME}/.local/bin/overleaf-codex"; fi
rm -rf "$DEST"
if [[ -L "$CLI" && "$(readlink "$CLI")" == "$DEST/scripts/overleaf_workflow.sh" ]]; then
  rm -f "$CLI"
fi
echo "Removed $DEST"
echo "Existing manuscript repositories and their AGENTS.md files were not modified."
