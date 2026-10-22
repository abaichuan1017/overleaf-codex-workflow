#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$ROOT/skill/overleaf-codex-workflow"
SCOPE="user"
TARGET_REPO=""
INSTALL_CLI=1

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh                    # install to ~/.agents/skills (recommended)
  ./install.sh --repo /path/repo  # install to <repo>/.agents/skills
  ./install.sh --no-cli           # do not install ~/.local/bin/overleaf-codex
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || { echo "--repo requires a path" >&2; exit 2; }
      SCOPE="repo"
      TARGET_REPO="$2"
      INSTALL_CLI=0
      shift 2
      ;;
    --no-cli)
      INSTALL_CLI=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$SCOPE" == "user" ]]; then
  [[ -n "${HOME:-}" ]] || { echo 'User installation requires HOME to be set.' >&2; exit 1; }
  DEST_BASE="${HOME}/.agents/skills"
else
  TARGET_REPO="$(cd "$TARGET_REPO" && pwd)"
  DEST_BASE="$TARGET_REPO/.agents/skills"
fi

DEST="$DEST_BASE/overleaf-codex-workflow"
CLI=""
if [[ "$INSTALL_CLI" -eq 1 ]]; then CLI="${HOME}/.local/bin/overleaf-codex"; fi
if [[ "$INSTALL_CLI" -eq 1 && ( -e "$CLI" || -L "$CLI" ) ]]; then
  [[ -L "$CLI" && "$(readlink "$CLI")" == */overleaf-codex-workflow/scripts/overleaf_workflow.sh ]] || {
    echo "Refusing to replace an unrelated CLI: $CLI" >&2
    exit 1
  }
fi
mkdir -p "$DEST_BASE"
STAGING="$(mktemp -d "$DEST_BASE/.overleaf-codex-install.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$SOURCE" "$STAGING/skill"
chmod +x "$STAGING/skill/scripts/overleaf_workflow.sh"
if [[ -e "$DEST" || -L "$DEST" ]]; then
  BACKUP="$(mktemp -d "$DEST_BASE/.overleaf-codex-backup.XXXXXX")"
  mv "$DEST" "$BACKUP/skill"
  echo "Previous skill preserved: $BACKUP/skill"
fi
mv "$STAGING/skill" "$DEST"

echo "Installed Codex skill: $DEST"

if [[ "$INSTALL_CLI" -eq 1 ]]; then
  BIN_DIR="${HOME}/.local/bin"
  mkdir -p "$BIN_DIR"
  ln -sfn "$DEST/scripts/overleaf_workflow.sh" "$CLI"
  echo "Installed CLI symlink: $BIN_DIR/overleaf-codex"
  case ":${PATH}:" in
    *":$BIN_DIR:"*) ;;
    *) echo "Note: add $BIN_DIR to PATH to run 'overleaf-codex' directly." ;;
  esac
fi

echo ""
echo "Codex usage:"
echo '  $overleaf-codex-workflow setup https://www.overleaf.com/project/<PROJECT_ID> ~/papers/my-paper'
echo '  $overleaf-codex-workflow pull'
echo '  $overleaf-codex-workflow status'
echo '  $overleaf-codex-workflow push'
