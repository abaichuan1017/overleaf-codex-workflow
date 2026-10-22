#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/overleaf-codex-installer.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
TEST_HOME="$TMP/user home"
TEST_REPO="$TMP/local repo"
mkdir -p "$TEST_HOME" "$TEST_REPO"
export GIT_AUTHOR_NAME="Workflow Test" GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Workflow Test" GIT_COMMITTER_EMAIL="test@example.com"
fail() { echo "FAIL: $*" >&2; exit 1; }
# Never install into the operator's actual home or overwrite their CLI.
env HOME="$TEST_HOME" bash "$ROOT/install.sh" >/dev/null
CLI="$TEST_HOME/.local/bin/overleaf-codex"
DEST="$TEST_HOME/.agents/skills/overleaf-codex-workflow"
[[ -L "$CLI" && -f "$DEST/SKILL.md" && -d "$DEST/references" ]] || fail 'incomplete install'
"$CLI" --help >/dev/null
# Exercise resource discovery through the CLI symlink, not just --help.
git init --bare --initial-branch=main "$TMP/remote.git" >/dev/null
git clone "$TMP/remote.git" "$TMP/seed" >/dev/null 2>&1
(
  cd "$TMP/seed"
  printf '\\documentclass{article}\n' > main.tex
  git add main.tex
  git commit -m 'CLI fixture' >/dev/null
  git push origin main >/dev/null 2>&1
)
"$CLI" setup "$TMP/remote.git" "$TMP/cli manuscript" >/dev/null 2>&1
[[ -f "$TMP/cli manuscript/AGENTS.md" ]] || fail 'symlink CLI could not find template'
# Installation upgrades preserve local modifications in a recoverable backup.
printf 'My local customization.\n' > "$DEST/local-note.txt"
env HOME="$TEST_HOME" bash "$ROOT/install.sh" >/dev/null
found=0
for backup in "$TEST_HOME/.agents/skills"/.overleaf-codex-backup.*/skill/local-note.txt; do
  if [[ -f "$backup" ]] && grep -q 'My local customization' "$backup"; then found=1; fi
done
[[ "$found" == 1 ]] || fail 'upgrade lost previous installation'
# Repo installs are self-contained and leave the user's global CLI unchanged.
link_before="$(readlink "$CLI")"
env HOME="$TEST_HOME" bash "$ROOT/install.sh" --repo "$TEST_REPO" >/dev/null
[[ -f "$TEST_REPO/.agents/skills/overleaf-codex-workflow/SKILL.md" ]] || fail 'repo install missing'
[[ "$(readlink "$CLI")" == "$link_before" ]] || fail 'repo install changed global CLI'
env HOME="$TEST_HOME" bash "$ROOT/uninstall.sh" --repo "$TEST_REPO" >/dev/null
[[ ! -e "$TEST_REPO/.agents/skills/overleaf-codex-workflow" && -L "$CLI" ]] || fail 'repo uninstall affected user install'
env HOME="$TEST_HOME" bash "$ROOT/uninstall.sh" >/dev/null
[[ ! -e "$DEST" && ! -L "$CLI" ]] || fail 'user uninstall incomplete'
[[ -f "$TMP/cli manuscript/main.tex" ]] || fail 'uninstall removed manuscript'
# An unrelated executable must not be replaced or removed.
printf '#!/bin/sh\nexit 0\n' > "$CLI"
if env HOME="$TEST_HOME" bash "$ROOT/install.sh" >"$TMP/failed.log" 2>&1; then fail 'unrelated CLI was replaced'; fi
[[ -f "$CLI" && ! -L "$CLI" ]] || fail 'unrelated CLI damaged'
env HOME="$TEST_HOME" bash "$ROOT/uninstall.sh" >/dev/null
[[ -f "$CLI" ]] || fail 'uninstall removed unrelated CLI'
echo 'PASS: isolated install, real CLI setup, upgrade backup, repo scope, and uninstall'
