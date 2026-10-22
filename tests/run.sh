#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Keep fixtures independent of the operator's Git identity, hooks, and settings.
TEST_CONFIG="$(mktemp -d "${TMPDIR:-/tmp}/overleaf-codex-config.XXXXXX")"
trap 'rm -rf "$TEST_CONFIG"' EXIT
export GIT_CONFIG_GLOBAL="$TEST_CONFIG/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
export GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME="Workflow Test" GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Workflow Test" GIT_COMMITTER_EMAIL="test@example.com"
git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main
for script in "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/skill/overleaf-codex-workflow/scripts/overleaf_workflow.sh" "$ROOT"/tests/*.sh; do
  bash -n "$script"
done
bash "$ROOT/tests/test.sh"
bash "$ROOT/tests/regressions.sh"
bash "$ROOT/tests/installer.sh"
echo 'PASS: all checks'
