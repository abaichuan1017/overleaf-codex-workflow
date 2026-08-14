---
name: overleaf-codex-workflow
description: Manage a safe Codex + Git + Overleaf manuscript workflow. Use to set up an Overleaf Git project locally, pull before editing, inspect sync status, generate project AGENTS.md guidance, and stage/confirm/push manuscript changes back to Overleaf. Never push unless the user explicitly requests it.
---

# Overleaf Codex Workflow

Use the bundled deterministic script for all Git/Overleaf operations. Do not reimplement Git synchronization ad hoc.

## Script location

Resolve this skill directory first, then run:

```bash
bash <skill-dir>/scripts/overleaf_workflow.sh <command> [args]
```

When installed by this repository's `install.sh`, the usual location is:

```bash
~/.agents/skills/overleaf-codex-workflow/scripts/overleaf_workflow.sh
```

## Commands

### Setup

When the user asks to configure or clone an Overleaf project:

```bash
bash <skill-dir>/scripts/overleaf_workflow.sh setup <overleaf-project-url|git-url|project-id> [directory]
```

The setup command must:

1. Clone the Overleaf Git repository.
2. Rename the Git remote to `overleaf`.
3. Use `master` as the Overleaf synchronization branch.
4. Create or extend a repository-root `AGENTS.md` with safe manuscript rules.
5. Keep Codex-local files out of Overleaf by adding them to `.git/info/exclude` rather than modifying the tracked `.gitignore`.
6. Never accept or store a token embedded in a URL.

If Git asks for credentials, tell the user to enter username `git` and their Overleaf Git authentication token as the password. Never ask the user to paste the token into chat.

### Pull

Before editing a manuscript, unless the user explicitly says not to access the network or not to pull, run:

```bash
bash <skill-dir>/scripts/overleaf_workflow.sh pull
```

If the working tree is dirty, or the local and remote histories diverge, stop. Do not auto-stash, merge, rebase, reset, or discard changes.

### Status

To inspect local/remote state without changing manuscript files:

```bash
bash <skill-dir>/scripts/overleaf_workflow.sh status
```

Report whether the local branch is ahead, behind, diverged, or synchronized, and summarize uncommitted changes.

### Push: mandatory two-step gate

Only begin a push if the user explicitly asks to upload, push, or synchronize local changes to Overleaf.

First run the preflight:

```bash
bash <skill-dir>/scripts/overleaf_workflow.sh push
```

This stages changes and records a cryptographic snapshot of the reviewed state, but it does not commit or push. Show the resulting diff summary to the user.

Do **not** continue automatically. Ask for explicit confirmation.

Only after the user confirms, run:

```bash
bash <skill-dir>/scripts/overleaf_workflow.sh push --confirm [commit message]
```

The confirmation step must abort if:

- the staged diff changed after review,
- HEAD changed after review,
- Overleaf changed after review,
- the remote is not an ancestor of the local branch,
- or another safety check fails.

Never use `git push --force`, `--force-with-lease`, `git reset --hard`, destructive checkout, or history rewriting for this workflow.

## Manuscript editing rules

After a successful pull, follow the repository's `AGENTS.md` and the user's request. Prefer focused edits. Preserve citations, labels, cross-references, numerical results, tables, figures, author metadata, and bibliography entries unless the user specifically requests changes to them.

If a local LaTeX compiler is available, compile or run the project's documented validation command after substantive edits. Do not install packages or change the TeX toolchain without permission.

## Boundaries

- Overleaf Git supports a single synchronization branch named `master`; push local `HEAD` to `overleaf/master` through the bundled script.
- Treat Overleaf as a collaboration remote, not as a place to store Codex configuration or secrets.
- Never place authentication tokens in `AGENTS.md`, Git remotes, shell history, tracked files, commit messages, or chat.
