---
name: overleaf-codex-workflow
description: Set up, pull, inspect, or push an Overleaf Git manuscript with reviewed synchronization. Use for Overleaf sync requests, not ordinary LaTeX editing.
---

# Overleaf Codex Workflow

Run `bash <skill-dir>/scripts/overleaf_workflow.sh <command>` from the manuscript repository. Resolve `<skill-dir>` from this skill's actual location; the installed `overleaf-codex` CLI is equivalent. Use the script for synchronization so its state checks stay active.

| Request | Command |
| --- | --- |
| Clone/configure a project | `setup <project-url\|git-url\|project-id> [directory]` |
| Update a clean checkout | `pull` |
| Fetch and inspect synchronization | `status` |
| Review an upload | `push` |
| Upload the reviewed state | `push --confirm "commit message"` |
| Refresh local project instructions | `init-agents` |
| Diagnose the environment | `doctor` |

Setup detects `main` or legacy `master`, names the remote `overleaf`, and keeps generated instructions local. For authentication, the user enters username `git` and their Overleaf token directly into Git's credential prompt; never request the token in chat or embed it in a command.

Pull before a new round of manuscript edits when the tree is clean and network access is allowed. If edits already exist, preserve them and report the state. Dirty trees, divergence, authentication failures, or changed review snapshots need explicit resolution; do not loop retries, auto-stash, merge divergent history, rebase, reset, discard, or force-push.

Only upload when the user explicitly requests it. Run `push`, inspect the staged diff and any outgoing commits, and show the review summary. Continue with `push --confirm` after the user approves that reviewed state. Existing approval for that exact reviewed state remains valid; do not ask twice. If the script rejects a stale snapshot, review again before uploading. Do not treat a generic instruction to edit a manuscript as upload approval.

Follow the manuscript's project instructions and requested scope. Validate substantive edits with the project's existing build command or available compiler; report skipped checks accurately. For setup details, instruction precedence, and recovery, read [references/workflow.md](references/workflow.md) only when relevant.
