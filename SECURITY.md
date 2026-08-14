# Security policy

## Secrets

Never report an Overleaf authentication token in an issue, log, screenshot, commit, prompt, or Git remote URL.

This project deliberately delegates authentication to Git and rejects HTTP(S) setup URLs containing embedded `user:password@host` credentials.

If a token is accidentally exposed, revoke it in Overleaf Account Settings and create a new token.

## Destructive Git behavior

A bug that causes force-push, history rewriting, silent conflict resolution, or unauthorized push should be treated as a security/safety issue.

The intended behavior is:

- no push without an explicit request,
- preflight before push,
- separate confirmation before commit/push,
- confirmation invalidated when reviewed state changes,
- no force push.
