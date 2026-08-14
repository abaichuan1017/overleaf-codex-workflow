#!/usr/bin/env bash
set -euo pipefail

PROGRAM="overleaf-codex"
REMOTE_DEFAULT="overleaf"
BRANCH_DEFAULT="master"
PENDING_FILE_REL="overleaf-codex-pending"

say() { printf '%s\n' "$*"; }
info() { printf '[%s] %s\n' "$PROGRAM" "$*"; }
warn() { printf '[%s] WARNING: %s\n' "$PROGRAM" "$*" >&2; }
die() { printf '[%s] ERROR: %s\n' "$PROGRAM" "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage:
  overleaf-codex setup <overleaf-project-url|git-url|project-id> [directory]
  overleaf-codex pull
  overleaf-codex status
  overleaf-codex push
  overleaf-codex push --confirm [commit message]
  overleaf-codex init-agents
  overleaf-codex doctor

Safety model:
  - setup clones Overleaf and creates local-only AGENTS.md guidance.
  - pull is fast-forward-only and requires a clean working tree.
  - push is two-step: preflight first, then explicit --confirm.
  - no force-push, auto-merge, auto-rebase, auto-stash, or destructive reset.
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || die "Not inside a Git repository."
}

git_dir() {
  git rev-parse --git-dir 2>/dev/null || die "Not inside a Git repository."
}

remote_name() {
  git config --local --get overleafCodex.remote 2>/dev/null || printf '%s\n' "$REMOTE_DEFAULT"
}

remote_branch() {
  git config --local --get overleafCodex.branch 2>/dev/null || printf '%s\n' "$BRANCH_DEFAULT"
}

ensure_managed_repo() {
  local remote branch
  repo_root >/dev/null
  remote="$(remote_name)"
  branch="$(remote_branch)"
  git remote get-url "$remote" >/dev/null 2>&1 || die "Managed remote '$remote' is missing. Run setup or configure overleafCodex.remote."
  [[ "$branch" == "master" ]] || die "Overleaf synchronization branch must be 'master' (configured: '$branch')."
}

working_tree_dirty() {
  [[ -n "$(git status --porcelain=v1 --untracked-files=all)" ]]
}

sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    die "Need sha256sum or shasum for push confirmation safety."
  fi
}

staged_hash() {
  git diff --cached --binary --no-ext-diff | sha256_stream
}

pending_file() {
  printf '%s/%s\n' "$(git_dir)" "$PENDING_FILE_REL"
}

clear_pending() {
  rm -f "$(pending_file)"
}

reject_embedded_secret() {
  local input="$1"
  # Reject http(s) URLs containing user:password@host. A username-only URL is fine.
  if [[ "$input" =~ ^https?://[^/@:]+:[^/@]+@ ]]; then
    die "Refusing a URL with an embedded password/token. Use a clean Git URL and let Git's credential helper handle authentication."
  fi
}

normalize_git_url() {
  local input="$1" clean id
  clean="${input%%#*}"
  clean="${clean%%\?*}"
  reject_embedded_secret "$clean"

  if [[ "$clean" =~ ^https?://www\.overleaf\.com/project/([^/]+)/*$ ]]; then
    id="${BASH_REMATCH[1]}"
    printf 'https://git.overleaf.com/%s\n' "$id"
    return
  fi

  if [[ "$clean" =~ ^https?://www\.overleaf\.com/([^/]+)/*$ ]]; then
    id="${BASH_REMATCH[1]}"
    printf 'https://git.overleaf.com/%s\n' "$id"
    return
  fi

  if [[ "$clean" =~ ^[A-Za-z0-9_-]+$ ]]; then
    printf 'https://git.overleaf.com/%s\n' "$clean"
    return
  fi

  # Accept an explicit Git URL/path for Overleaf Server Pro and local tests.
  if [[ "$clean" == *"://"* || "$clean" == /* || "$clean" == ./* || "$clean" == ../* || "$clean" == git@* ]]; then
    printf '%s\n' "$clean"
    return
  fi

  die "Could not understand '$input' as an Overleaf project URL, Git URL, or project id."
}

default_directory_name() {
  local input="$1" clean base
  clean="${input%%#*}"
  clean="${clean%%\?*}"
  clean="${clean%/}"
  base="${clean##*/}"
  [[ -n "$base" ]] || base="overleaf-paper"
  printf '%s\n' "$base"
}

add_info_exclude() {
  local root exclude marker
  root="$(repo_root)"
  exclude="$(git_dir)/info/exclude"
  marker="# overleaf-codex-workflow local-only files"
  mkdir -p "$(dirname "$exclude")"
  touch "$exclude"
  if ! grep -Fqx "$marker" "$exclude"; then
    cat >> "$exclude" <<'EOF_EXCLUDE'

# overleaf-codex-workflow local-only files
/AGENTS.md
/AGENTS.override.md
/.agents/
/.codex/
EOF_EXCLUDE
  fi
  info "Codex-local files excluded via .git/info/exclude (not pushed to Overleaf)."
}

skill_dir_from_script() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$script_dir/.." && pwd
}

init_agents() {
  local root agents override target template label
  root="$(repo_root)"
  agents="$root/AGENTS.md"
  override="$root/AGENTS.override.md"
  template="$(skill_dir_from_script)/assets/AGENTS.block.md"
  [[ -f "$template" ]] || die "AGENTS template missing: $template"

  # A tracked AGENTS.md cannot be made local-only with .git/info/exclude.
  # In that case use Codex's higher-precedence AGENTS.override.md instead.
  if git ls-files --error-unmatch AGENTS.md >/dev/null 2>&1; then
    if git ls-files --error-unmatch AGENTS.override.md >/dev/null 2>&1; then
      die "Both AGENTS.md and AGENTS.override.md are already tracked. Refusing to modify tracked Codex guidance during setup."
    fi
    target="$override"
    label="AGENTS.override.md"
    warn "AGENTS.md is already tracked; using local-only AGENTS.override.md so workflow guidance is not pushed to Overleaf."
  else
    target="$agents"
    label="AGENTS.md"
  fi

  if [[ ! -f "$target" ]]; then
    {
      printf '# %s\n\n' "$label"
      cat "$template"
      printf '\n'
    } > "$target"
    info "Created $target"
  elif grep -Fq '<!-- overleaf-codex-workflow:start -->' "$target"; then
    info "$label already contains the Overleaf workflow block; leaving it unchanged."
  else
    {
      printf '\n\n'
      cat "$template"
      printf '\n'
    } >> "$target"
    info "Appended Overleaf workflow guidance to existing $label"
  fi

  add_info_exclude
}

fetch_remote() {
  local remote branch
  remote="$(remote_name)"
  branch="$(remote_branch)"
  info "Fetching $remote/$branch ..."
  git fetch --prune "$remote" "$branch"
}

remote_ref() {
  printf 'refs/remotes/%s/%s\n' "$(remote_name)" "$(remote_branch)"
}

ensure_remote_ref() {
  local ref
  ref="$(remote_ref)"
  git rev-parse --verify "$ref" >/dev/null 2>&1 || die "Remote tracking ref '$ref' not found after fetch."
}

print_sync_counts() {
  local ref counts ahead behind
  ref="$(remote_ref)"
  counts="$(git rev-list --left-right --count HEAD..."$ref")"
  ahead="${counts%%[[:space:]]*}"
  behind="${counts##*[[:space:]]}"
  printf 'ahead=%s behind=%s\n' "$ahead" "$behind"
}

cmd_setup() {
  require_cmd git
  [[ $# -ge 1 && $# -le 2 ]] || { usage; exit 2; }
  local input="$1" url dir remote current_branch root
  url="$(normalize_git_url "$input")"
  dir="${2:-$(default_directory_name "$input")}" 

  if [[ -e "$dir" ]] && [[ -n "$(ls -A "$dir" 2>/dev/null || true)" ]]; then
    die "Target directory '$dir' already exists and is not empty."
  fi

  info "Cloning Overleaf project into '$dir' ..."
  info "If Git prompts for credentials, use username 'git' and your Overleaf Git authentication token as the password. Do not put the token in the URL."
  git clone "$url" "$dir"

  cd "$dir"
  if git remote get-url origin >/dev/null 2>&1; then
    git remote rename origin "$REMOTE_DEFAULT"
  fi

  remote="$REMOTE_DEFAULT"
  git config --local overleafCodex.remote "$remote"
  git config --local overleafCodex.branch "$BRANCH_DEFAULT"

  fetch_remote
  ensure_remote_ref

  current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ "$current_branch" != "$BRANCH_DEFAULT" ]]; then
    if git show-ref --verify --quiet "refs/heads/$BRANCH_DEFAULT"; then
      git checkout "$BRANCH_DEFAULT"
    else
      git checkout -b "$BRANCH_DEFAULT" --track "$(remote_ref)"
    fi
  fi
  git branch --set-upstream-to="$remote/$BRANCH_DEFAULT" "$BRANCH_DEFAULT" >/dev/null 2>&1 || true

  init_agents
  clear_pending
  root="$(repo_root)"

  say ""
  info "Setup complete."
  say "Repository: $root"
  say "Remote:     $remote -> $(git remote get-url "$remote")"
  say "Branch:     $BRANCH_DEFAULT"
  say "AGENTS.md:  local-only (excluded from Overleaf)"
  say ""
  say "Next: cd '$root' && codex"
  say "Then use: \$overleaf-codex-workflow pull"
}

cmd_pull() {
  require_cmd git
  ensure_managed_repo
  clear_pending

  if working_tree_dirty; then
    git status --short
    die "Working tree is dirty. Commit/review/stash manually before pulling; this workflow never auto-stashes or overwrites local work."
  fi

  fetch_remote
  ensure_remote_ref

  local ref
  ref="$(remote_ref)"
  if git merge-base --is-ancestor HEAD "$ref"; then
    if [[ "$(git rev-parse HEAD)" == "$(git rev-parse "$ref")" ]]; then
      info "Already synchronized with $(remote_name)/$(remote_branch)."
    else
      git merge --ff-only "$ref"
      info "Pulled latest Overleaf changes (fast-forward only)."
    fi
  elif git merge-base --is-ancestor "$ref" HEAD; then
    info "Local branch is ahead of Overleaf; no remote changes to pull."
  else
    die "Local and Overleaf histories have diverged. Resolve explicitly; no automatic merge/rebase will be performed."
  fi
}

cmd_status() {
  require_cmd git
  ensure_managed_repo
  fetch_remote
  ensure_remote_ref

  local remote branch ref counts ahead behind
  remote="$(remote_name)"
  branch="$(remote_branch)"
  ref="$(remote_ref)"
  counts="$(git rev-list --left-right --count HEAD..."$ref")"
  ahead="${counts%%[[:space:]]*}"
  behind="${counts##*[[:space:]]}"

  say "Repository: $(repo_root)"
  say "Current:    $(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD)"
  say "Overleaf:   $remote/$branch"
  say "HEAD:       $(git rev-parse --short HEAD)"
  say "Remote:     $(git rev-parse --short "$ref")"
  say "Ahead:      $ahead commit(s)"
  say "Behind:     $behind commit(s)"

  if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then
    say "Sync state: synchronized"
  elif [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then
    say "Sync state: local ahead"
  elif [[ "$ahead" -eq 0 && "$behind" -gt 0 ]]; then
    say "Sync state: Overleaf ahead"
  else
    say "Sync state: DIVERGED"
  fi

  if working_tree_dirty; then
    say ""
    say "Uncommitted changes:"
    git status --short
  else
    say "Working tree: clean"
  fi
}

write_pending() {
  local file head remote_hash staged
  file="$(pending_file)"
  head="$(git rev-parse HEAD)"
  remote_hash="$(git rev-parse "$(remote_ref)")"
  staged="$(staged_hash)"
  cat > "$file" <<EOF_PENDING
version=1
head=$head
remote=$remote_hash
staged=$staged
EOF_PENDING
}

pending_value() {
  local key="$1" file
  file="$(pending_file)"
  sed -n "s/^${key}=//p" "$file" | head -n 1
}

cmd_push_preflight() {
  require_cmd git
  ensure_managed_repo
  clear_pending
  fetch_remote
  ensure_remote_ref

  local ref counts ahead behind
  ref="$(remote_ref)"
  counts="$(git rev-list --left-right --count HEAD..."$ref")"
  ahead="${counts%%[[:space:]]*}"
  behind="${counts##*[[:space:]]}"

  if [[ "$behind" -gt 0 ]]; then
    if [[ "$ahead" -gt 0 ]]; then
      die "Local and Overleaf histories have diverged. Resolve explicitly before push."
    fi
    die "Overleaf is ahead by $behind commit(s). Pull before push. If you have edits, preserve them manually first; this workflow will not auto-stash."
  fi

  git add -A
  git diff --cached --check || die "Staged changes fail 'git diff --check'. Fix whitespace/conflict-marker issues before push."

  if git diff --cached --quiet && [[ "$ahead" -eq 0 ]]; then
    info "Nothing to push: no staged changes and no local commits ahead of Overleaf."
    return 0
  fi

  write_pending

  say ""
  say "=== Push preflight (NO COMMIT / NO PUSH YET) ==="
  say "Repository: $(repo_root)"
  say "Target:     $(remote_name)/$(remote_branch)"
  say "Local commits already ahead: $ahead"
  say ""
  say "Staged diffstat:"
  git diff --cached --stat || true
  say ""
  say "Staged files:"
  git diff --cached --name-status || true
  say ""
  say "Review the staged changes. If they are correct, explicitly confirm, then run:"
  say "  overleaf-codex push --confirm \"your commit message\""
  say ""
  say "Safety snapshot recorded; confirmation will fail if HEAD, staged content, or Overleaf changes before confirmation."
}

cmd_push_confirm() {
  require_cmd git
  ensure_managed_repo
  local file expected_head expected_remote expected_staged current_staged msg ref
  file="$(pending_file)"
  [[ -f "$file" ]] || die "No pending push preflight. Run 'push' first and review the diff."

  expected_head="$(pending_value head)"
  expected_remote="$(pending_value remote)"
  expected_staged="$(pending_value staged)"
  [[ -n "$expected_head" && -n "$expected_remote" && -n "$expected_staged" ]] || die "Pending push state is invalid. Run preflight again."

  [[ "$(git rev-parse HEAD)" == "$expected_head" ]] || die "HEAD changed after preflight. Run push preflight again."
  current_staged="$(staged_hash)"
  [[ "$current_staged" == "$expected_staged" ]] || die "Staged content changed after preflight. Run push preflight again."
  git diff --quiet || die "Tracked files changed after preflight without being staged. Run push preflight again."
  [[ -z "$(git ls-files --others --exclude-standard)" ]] || die "New untracked files appeared after preflight. Run push preflight again."

  fetch_remote
  ensure_remote_ref
  ref="$(remote_ref)"
  [[ "$(git rev-parse "$ref")" == "$expected_remote" ]] || die "Overleaf changed after preflight. Pull/review and run preflight again."
  git merge-base --is-ancestor "$ref" HEAD || die "Overleaf remote is not an ancestor of local HEAD. Refusing to push divergent history."

  msg="${1:-Update manuscript via Codex}"

  if ! git diff --cached --quiet; then
    git commit -m "$msg"
  else
    info "No staged file changes; pushing existing local commit(s) only."
  fi

  # Re-check ancestry after the optional commit.
  git merge-base --is-ancestor "$ref" HEAD || die "Safety check failed after commit."

  info "Pushing local HEAD to $(remote_name)/master ..."
  git push "$(remote_name)" HEAD:master
  clear_pending
  info "Push complete."
}

cmd_doctor() {
  say "Overleaf Codex Workflow doctor"
  say ""
  if command -v git >/dev/null 2>&1; then
    say "[ok] git: $(git --version)"
  else
    say "[missing] git"
  fi
  if command -v codex >/dev/null 2>&1; then
    say "[ok] codex: $(command -v codex)"
  else
    say "[optional] codex CLI not found on PATH"
  fi
  if command -v latexmk >/dev/null 2>&1; then
    say "[ok] latexmk: $(command -v latexmk)"
  else
    say "[optional] latexmk not found; Overleaf can still compile remotely"
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    say "[ok] repository: $(repo_root)"
    if git remote get-url "$(remote_name)" >/dev/null 2>&1; then
      say "[ok] managed remote: $(remote_name) -> $(git remote get-url "$(remote_name)")"
    else
      say "[missing] managed remote '$(remote_name)'"
    fi
    local helper
    helper="$(git config --get credential.helper 2>/dev/null || true)"
    if [[ -n "$helper" ]]; then
      say "[ok] Git credential helper configured: $helper"
    else
      say "[note] No credential.helper detected in this repo/config chain. Git may ask for your Overleaf token on each network operation."
    fi
  else
    say "[note] not currently inside a Git repository"
  fi
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    setup)
      shift
      cmd_setup "$@"
      ;;
    pull)
      shift
      [[ $# -eq 0 ]] || die "pull takes no arguments"
      cmd_pull
      ;;
    status)
      shift
      [[ $# -eq 0 ]] || die "status takes no arguments"
      cmd_status
      ;;
    push)
      shift
      if [[ "${1:-}" == "--confirm" ]]; then
        shift
        [[ $# -le 1 ]] || die "push --confirm accepts at most one commit-message argument"
        cmd_push_confirm "${1:-}"
      else
        [[ $# -eq 0 ]] || die "Unknown push arguments. Use 'push' or 'push --confirm [message]'."
        cmd_push_preflight
      fi
      ;;
    init-agents)
      shift
      [[ $# -eq 0 ]] || die "init-agents takes no arguments"
      ensure_managed_repo
      init_agents
      ;;
    doctor)
      shift
      [[ $# -eq 0 ]] || die "doctor takes no arguments"
      cmd_doctor
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      usage >&2
      die "Unknown command: $cmd"
      ;;
  esac
}

main "$@"
