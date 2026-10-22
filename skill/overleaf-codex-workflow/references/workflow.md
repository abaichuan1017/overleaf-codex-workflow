# Setup and recovery

## Project setup

`setup` accepts an Overleaf Cloud project URL, its Git URL, a project ID, or an explicit Server Pro Git URL. It detects the remote default branch (`main` or legacy `master`) and records the remote and branch in local Git configuration. Existing installations keep their configured branch; no history migration is needed.

Git integration must be available for the user's Overleaf project. Credentials belong in Git's own prompt and a trusted credential helper. If authentication fails, let the user fix it locally before retrying; the tool does not manage tokens.

## Local instructions

`init-agents` creates or updates only the marked workflow block, preserving other text. An updated block gets a local `.overleaf-codex.bak` copy; the next update replaces that backup. Codex chooses `AGENTS.override.md` instead of `AGENTS.md` in the same directory, so:

- Existing local overrides receive the block directly.
- When `AGENTS.md` is tracked and no override exists, setup copies its current content into a local override before adding the block.
- A tracked override is never modified by setup. Resolve instruction ownership explicitly first.

Copied project rules are a snapshot: after collaborators change the tracked `AGENTS.md`, reconcile those changes into the local override. Refreshing the workflow block does not synchronize copied project rules. Restart the Codex session to reload changed project instructions.

Generated instructions, their backup, `.agents/`, and `.codex/` are excluded through Git's local `info/exclude`. This does not hide files already tracked by the manuscript repository.

## Review and upload

`push` stages all non-ignored changes from the repository root. It checks whitespace/conflict markers, shows outgoing commits and staged files, and stores a local review snapshot. Inspect `git diff --cached` and, for existing commits, `git diff overleaf/<branch> HEAD` before approval. The summary alone is not a content review.

`push --confirm` checks the target endpoint, branch, HEAD, index, working tree, and fetched remote again before committing and pushing. The CLI flag records the operator's confirmation; it cannot verify a conversation's authorization itself. A Git hook that changes the reviewed tree causes upload to stop. A failed network push may leave a local commit; inspect `status` and run a fresh review before retrying. No rollback, force-push, or token reset is automatic.

`status` fetches remote state but does not edit manuscript files. Overleaf may create a Git commit when fetched; this is part of its Git bridge behavior.

## Environment checks

`doctor` checks local commands and repository configuration. It does not authenticate to Overleaf or compile a manuscript. Use the project's documented build command for compilation; this skill does not select a GPT model, call an LLM API, or install a TeX distribution.
