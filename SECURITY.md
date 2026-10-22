# Security policy

## Secrets

Never report an Overleaf authentication token in an issue, log, screenshot, commit, prompt, or Git remote URL.

Authentication is delegated to Git. HTTP(S) URLs with embedded credentials are rejected; the standard username-only `git@` form is allowed. Managed fetch and push endpoints must match.

If a token is accidentally exposed, revoke it in Overleaf Account Settings and create a new token.

## Destructive Git behavior

A bug that causes force-push, history rewriting, silent conflict resolution, or unauthorized push should be treated as a security/safety issue.

The intended behavior is:

- no push without an explicit request,
- preflight before push,
- separate confirmation before commit/push,
- confirmation invalidated when reviewed state changes,
- no force push.

The CLI cannot authenticate a human's approval: the agent/operator must obtain approval for the reviewed state before using `--confirm`. Local integration tests validate Git behavior, not real Overleaf credentials or remote compilation.
