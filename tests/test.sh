#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/skill/overleaf-codex-workflow/scripts/overleaf_workflow.sh"
TMP="${TMPDIR:-/tmp}/overleaf-codex-workflow-test-$$"
REMOTE="$TMP/remote.git"
SEED="$TMP/seed"
WORK="$TMP/work"
COLLAB="$TMP/collab"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

export GIT_AUTHOR_NAME="Workflow Test"
export GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Workflow Test"
export GIT_COMMITTER_EMAIL="test@example.com"

mkdir -p "$TMP"
git init --bare "$REMOTE" >/dev/null

git clone "$REMOTE" "$SEED" >/dev/null 2>&1
cd "$SEED"
git checkout -b master >/dev/null 2>&1
cat > main.tex <<'TEX'
\\documentclass{article}
\\begin{document}
Hello Overleaf.
\\end{document}
TEX
git add main.tex
git commit -m "Initial manuscript" >/dev/null
git push origin master >/dev/null 2>&1

git --git-dir="$REMOTE" symbolic-ref HEAD refs/heads/master

cd "$TMP"
bash "$SCRIPT" setup "$REMOTE" "$WORK" >/dev/null
cd "$WORK"

[[ -f AGENTS.md ]]
grep -q 'overleaf-codex-workflow:start' AGENTS.md
git check-ignore -q AGENTS.md
[[ "$(git remote)" == "overleaf" ]]
[[ "$(git branch --show-current)" == "master" ]]

bash "$SCRIPT" pull >/dev/null
printf '\nLocal edit.\n' >> main.tex

# Pull must reject a dirty tree.
if bash "$SCRIPT" pull >/dev/null 2>&1; then
  echo "FAIL: pull accepted dirty tree" >&2
  exit 1
fi

# Push preflight must not create a commit.
HEAD_BEFORE="$(git rev-parse HEAD)"
bash "$SCRIPT" push >/dev/null
[[ "$(git rev-parse HEAD)" == "$HEAD_BEFORE" ]]
git diff --cached --quiet && { echo "FAIL: push preflight did not stage edit" >&2; exit 1; }

# Change staged content after review; confirmation must fail.
printf '\nChanged after review.\n' >> main.tex
git add main.tex
if bash "$SCRIPT" push --confirm "Should fail" >/dev/null 2>&1; then
  echo "FAIL: confirmation accepted changed staged content" >&2
  exit 1
fi

# Re-run preflight, then confirm successfully.
bash "$SCRIPT" push >/dev/null
bash "$SCRIPT" push --confirm "Local manuscript edit" >/dev/null
[[ "$(git rev-parse HEAD)" != "$HEAD_BEFORE" ]]

# Simulate collaborator changing Overleaf after our preflight.
git clone "$REMOTE" "$COLLAB" >/dev/null 2>&1
cd "$COLLAB"
printf '\nRemote collaborator edit.\n' >> main.tex
git add main.tex
git commit -m "Remote collaborator edit" >/dev/null
git push origin master >/dev/null 2>&1

cd "$WORK"
printf '\nAnother local edit.\n' >> main.tex
# Preflight should see remote ahead and refuse.
if bash "$SCRIPT" push >/dev/null 2>&1; then
  echo "FAIL: push preflight accepted Overleaf-ahead state" >&2
  exit 1
fi

# Preserve the intent of the local edit manually for test, then pull and reapply it.
git checkout -- main.tex
bash "$SCRIPT" pull >/dev/null
printf '\nAnother local edit.\n' >> main.tex

# Preflight, then remote changes again; confirm must fail due stale remote.
bash "$SCRIPT" push >/dev/null
cd "$COLLAB"
git pull --ff-only origin master >/dev/null 2>&1
printf '\nSecond remote edit.\n' >> main.tex
git add main.tex
git commit -m "Second remote edit" >/dev/null
git push origin master >/dev/null 2>&1
cd "$WORK"
if bash "$SCRIPT" push --confirm "Should fail stale remote" >/dev/null 2>&1; then
  echo "FAIL: confirmation accepted stale remote" >&2
  exit 1
fi


# Verify setup avoids modifying a tracked AGENTS.md and uses local override.
TRACKED_SEED="$TMP/tracked-seed"
TRACKED_REMOTE="$TMP/tracked-remote.git"
TRACKED_WORK="$TMP/tracked-work"
git init --bare "$TRACKED_REMOTE" >/dev/null
git clone "$TRACKED_REMOTE" "$TRACKED_SEED" >/dev/null 2>&1
cd "$TRACKED_SEED"
git checkout -b master >/dev/null 2>&1
printf '# Existing tracked instructions\n' > AGENTS.md
printf '\\documentclass{article}\n' > main.tex
git add AGENTS.md main.tex
git commit -m "Tracked agents fixture" >/dev/null
git push origin master >/dev/null 2>&1
git --git-dir="$TRACKED_REMOTE" symbolic-ref HEAD refs/heads/master
cd "$TMP"
bash "$SCRIPT" setup "$TRACKED_REMOTE" "$TRACKED_WORK" >/dev/null
cd "$TRACKED_WORK"
[[ "$(cat AGENTS.md)" == '# Existing tracked instructions' ]]
[[ -f AGENTS.override.md ]]
grep -q 'overleaf-codex-workflow:start' AGENTS.override.md
git check-ignore -q AGENTS.override.md
git diff --quiet -- AGENTS.md

echo "PASS: overleaf-codex-workflow safety tests"
