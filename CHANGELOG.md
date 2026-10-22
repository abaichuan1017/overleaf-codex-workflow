# Changelog

## 0.2.0 - 2026-10-23

- Detect Overleaf's current `main` and legacy `master` branches instead of hardcoding `master`.
- Shorten the bilingual README and Skill entrypoint; load setup/recovery details only when needed, following current OpenAI guidance.
- Resolve installed CLI symlinks correctly and run synchronization from the repository root, including linked worktrees.
- Preserve project instructions when creating an override; update only the managed block with a local backup.
- Bind upload reviews to the endpoint and branch, show outgoing commits, and reject commit-hook changes or mismatched fetch/push endpoints.
- Preserve previous skill installations during upgrades and avoid changing the global CLI for repository-local installs.
- Expand offline integration tests and run them on Linux and macOS.

## 0.1.0 - 2026-08-15

- Initial open-source release.
- Bilingual Chinese/English GitHub README.
- Codex Agent Skill with `setup`, `pull`, `status`, and gated `push` workflow.
- Automatic local-only `AGENTS.md` initialization.
- Overleaf `master` branch enforcement.
- Push snapshot validation for staged diff, HEAD, and remote state.
- Local fake-Overleaf safety test suite.
