#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/skill/overleaf-codex-workflow/scripts/overleaf_workflow.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/overleaf-codex-regression.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME="Workflow Test" GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Workflow Test" GIT_COMMITTER_EMAIL="test@example.com"
fail() { echo "FAIL: $*" >&2; exit 1; }
reject() {
  if "$@" >"$TMP/rejected.log" 2>&1; then fail "unexpected success: $*"; fi
}
fixture() {
  local name="$1" branch="$2"
  git init --bare --initial-branch="$branch" "$TMP/$name.git" >/dev/null
  git clone "$TMP/$name.git" "$TMP/$name-seed" >/dev/null 2>&1
  (
    cd "$TMP/$name-seed"
    printf '\\documentclass{article}\n\\begin{document}Hello.\\end{document}\n' > main.tex
    git add main.tex
    git commit -m 'Initial manuscript' >/dev/null
    git push origin "$branch" >/dev/null 2>&1
  )
}

for branch in main master; do
  fixture "$branch" "$branch"
  bash "$SCRIPT" setup "$TMP/$branch.git" "$TMP/$branch-work" >/dev/null 2>&1
  cd "$TMP/$branch-work"
  [[ "$(git config overleafCodex.branch)" == "$branch" ]] || fail 'wrong branch detection'
  git check-ignore -q AGENTS.md || fail 'instructions are not local'
  [[ "$(bash "$SCRIPT" status 2>/dev/null)" == *'Sync state: synchronized'* ]] || fail 'wrong initial status'
  mkdir sections
  printf 'Section.\n' > sections/intro.tex
  printf 'Root edit.\n' >> main.tex
  cd sections
  bash "$SCRIPT" push >/dev/null 2>&1
  git diff --cached --name-only | grep -qx main.tex || fail 'subdirectory push omitted root edit'
  git diff --cached --name-only | grep -qx sections/intro.tex || fail 'subdirectory push omitted section'
  bash "$SCRIPT" push --confirm 'Edit from subdirectory' >/dev/null 2>&1
  [[ "$(git rev-parse HEAD)" == "$(git --git-dir="$TMP/$branch.git" rev-parse "refs/heads/$branch")" ]] || fail 'push did not reach target'
  cd ..
  # Existing commits must be visible in the preflight even with no staged diff.
  printf 'Already committed.\n' >> main.tex
  git add main.tex
  git commit -m 'Visible outgoing commit' >/dev/null
  [[ "$(bash "$SCRIPT" push 2>/dev/null)" == *'Visible outgoing commit'* ]] || fail 'outgoing commits absent from review'
  bash "$SCRIPT" push --confirm >/dev/null 2>&1
  # Unstaged and new files invalidate approval.
  printf 'Reviewed.\n' >> main.tex
  bash "$SCRIPT" push >/dev/null 2>&1
  printf 'After review.\n' >> main.tex
  reject bash "$SCRIPT" push --confirm
  bash "$SCRIPT" push >/dev/null 2>&1
  printf 'New file.\n' > new.tex
  reject bash "$SCRIPT" push --confirm
  bash "$SCRIPT" push >/dev/null 2>&1
  bash "$SCRIPT" push --confirm >/dev/null 2>&1
  # No-change push creates no approval or commit.
  before="$(git rev-parse HEAD)"
  bash "$SCRIPT" push >/dev/null 2>&1
  reject bash "$SCRIPT" push --confirm
  [[ "$(git rev-parse HEAD)" == "$before" ]] || fail 'no-op push committed'
  # Linked worktrees have their own review state and share local excludes.
  git worktree add -b "linked-$branch" "$TMP/$branch-linked" >/dev/null 2>&1
  cd "$TMP/$branch-linked"
  bash "$SCRIPT" init-agents >/dev/null
  git check-ignore -q AGENTS.md || fail 'worktree instructions not excluded'
  printf 'Linked edit.\n' >> main.tex
  bash "$SCRIPT" push >/dev/null 2>&1
  [[ -f "$(git rev-parse --git-path overleaf-codex-pending)" ]] || fail 'missing worktree review snapshot'
  bash "$SCRIPT" push --confirm >/dev/null 2>&1
  echo "PASS: $branch setup/edit/status/review/push and linked worktree"
done

# Creating an override must retain project rules because overrides shadow AGENTS.md.
fixture instructions main
cd "$TMP/instructions-seed"
printf '# Project rules\nDo not alter experimental measurements.\n' > AGENTS.md
git add AGENTS.md
git commit -m 'Project instructions' >/dev/null
git push origin main >/dev/null 2>&1
bash "$SCRIPT" setup "$TMP/instructions.git" "$TMP/instructions-work" >/dev/null 2>&1
cd "$TMP/instructions-work"
grep -q 'Do not alter experimental measurements' AGENTS.override.md || fail 'override lost project rules'
git diff --exit-code -- AGENTS.md >/dev/null
# Refresh a legacy managed block while preserving surrounding custom instructions.
printf '# Local rule\nKeep this text.\n<!-- overleaf-codex-workflow:start -->\nOld block.\n<!-- overleaf-codex-workflow:end -->\nEnd rule.\n' > AGENTS.override.md
bash "$SCRIPT" init-agents >/dev/null 2>&1
grep -q 'Keep this text' AGENTS.override.md || fail 'refresh lost prefix'
grep -q 'End rule' AGENTS.override.md || fail 'refresh lost suffix'
grep -q 'Old block' AGENTS.override.md.overleaf-codex.bak || fail 'old block not backed up'
git check-ignore -q AGENTS.override.md.overleaf-codex.bak || fail 'backup not excluded'
# A malformed managed block must fail without deleting surrounding text.
printf '# Keep me\n<!-- overleaf-codex-workflow:start -->\nUnterminated.\n' > AGENTS.override.md
before="$(git hash-object AGENTS.override.md)"
reject bash "$SCRIPT" init-agents
[[ "$(git hash-object AGENTS.override.md)" == "$before" ]] || fail 'malformed block lost content'
# Existing untracked override is the active instruction target.
printf '# Active local override\n' > AGENTS.override.md
bash "$SCRIPT" init-agents >/dev/null 2>&1
grep -q 'overleaf-codex-workflow:start' AGENTS.override.md || fail 'existing override was ignored'
# A tracked override must not be changed.
git add -f AGENTS.override.md
git commit -m 'Track override fixture' >/dev/null
before="$(git hash-object AGENTS.override.md)"
reject bash "$SCRIPT" init-agents
[[ "$(git hash-object AGENTS.override.md)" == "$before" ]] || fail 'tracked override was modified'
echo 'PASS: instruction precedence, preservation, refresh, and backups'

# Changed endpoints with the same history must not reuse an approval.
cd "$TMP/main-work"
bash "$SCRIPT" pull >/dev/null 2>&1
printf 'Endpoint review.\n' >> main.tex
bash "$SCRIPT" push >/dev/null 2>&1
git clone --bare "$TMP/main.git" "$TMP/mirror.git" >/dev/null 2>&1
git remote set-url overleaf "$TMP/mirror.git"
reject bash "$SCRIPT" push --confirm
git remote set-url overleaf "$TMP/main.git"
git remote set-url --push overleaf "$TMP/mirror.git"
reject bash "$SCRIPT" push
git config --unset-all remote.overleaf.pushurl
# Changing HEAD after review invalidates the snapshot, even for identical files.
bash "$SCRIPT" push >/dev/null 2>&1
git commit --allow-empty --only -m 'New HEAD after review' >/dev/null
reject bash "$SCRIPT" push --confirm
# Commit hook mutations cannot reach the remote under an older approval.
bash "$SCRIPT" push >/dev/null 2>&1
remote_before="$(git --git-dir="$TMP/main.git" rev-parse main)"
mkdir -p "$(git rev-parse --git-path hooks)"
cat > "$(git rev-parse --git-path hooks/pre-commit)" <<'HOOK'
#!/usr/bin/env bash
printf 'Injected by hook.\n' >> main.tex
git add main.tex
HOOK
chmod +x "$(git rev-parse --git-path hooks/pre-commit)"
reject bash "$SCRIPT" push --confirm
[[ "$(git --git-dir="$TMP/main.git" rev-parse main)" == "$remote_before" ]] || fail 'hook changes reached remote'
echo 'PASS: endpoint binding and commit-hook mutation rejection'

# Divergence must stop without changing local HEAD or files.
cd "$TMP/master-work"
bash "$SCRIPT" pull >/dev/null 2>&1
git clone "$TMP/master.git" "$TMP/diverged-collab" >/dev/null 2>&1
(
  cd "$TMP/diverged-collab"
  printf 'Collaborator.\n' >> main.tex
  git add main.tex
  git commit -m 'Remote divergence' >/dev/null
  git push origin master >/dev/null 2>&1
)
printf 'Local fork.\n' >> main.tex
git add main.tex
git commit -m 'Local divergence' >/dev/null
before="$(git rev-parse HEAD)"
reject bash "$SCRIPT" pull
reject bash "$SCRIPT" push
[[ "$(git rev-parse HEAD)" == "$before" ]] || fail 'divergence rewrote local history'
[[ "$(bash "$SCRIPT" status 2>/dev/null)" == *'Sync state: DIVERGED'* ]] || fail 'divergence not reported'
echo 'PASS: divergent history preserved'

reject bash "$SCRIPT" setup 'https://user:fake-secret@git.overleaf.com/example' "$TMP/secret-work"
reject bash "$SCRIPT" setup 'https://fake-secret@git.overleaf.com/example' "$TMP/secret-work"
[[ ! -e "$TMP/secret-work" ]] || fail 'credential URL was cloned'
echo 'PASS: embedded credentials rejected before cloning'
