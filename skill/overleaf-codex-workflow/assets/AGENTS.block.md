<!-- overleaf-codex-workflow:start -->
## Overleaf + Codex workflow

- This manuscript uses Overleaf Git as its collaboration remote. The managed remote is `overleaf`; the Overleaf synchronization branch is `master`.
- Before editing manuscript content, pull the latest Overleaf state with `$overleaf-codex-workflow pull`, unless the user explicitly requests offline/local-only work or says not to pull.
- If pull reports a dirty tree, divergence, or a conflict risk, stop and explain the state. Do not auto-stash, auto-merge, rebase, reset, discard, or overwrite work.
- Make focused edits that match the user's request. Do not silently alter scientific claims, citations, labels, numerical results, tables, figures, author metadata, or bibliography entries.
- Preserve LaTeX structure and project conventions. Reuse existing macros and commands where practical.
- If the project documents a build/test command, run it after substantive edits. Otherwise, use an already-installed LaTeX compiler when practical; do not install or reconfigure the TeX toolchain without permission.
- Never push merely because edits are finished. A push requires an explicit user request to upload/push/sync to Overleaf.
- For a push, use `$overleaf-codex-workflow push` first. Show the preflight/diff summary and wait for explicit confirmation. Only then use `$overleaf-codex-workflow push --confirm`.
- Never force-push or rewrite Overleaf history. Never put an Overleaf authentication token in files, Git remote URLs, commits, logs, prompts, or chat.
<!-- overleaf-codex-workflow:end -->
