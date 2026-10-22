<!-- overleaf-codex-workflow:start -->
## Overleaf synchronization

- Collaboration remote: `{{REMOTE}}`, branch: `{{BRANCH}}`. Use `$overleaf-codex-workflow` or `overleaf-codex` for synchronization.
- Pull before a new editing round when the tree is clean and network use is allowed. Preserve existing edits; stop on dirty trees or divergence instead of auto-stashing, rebasing, resetting, or overwriting work.
- Follow the requested manuscript scope. Preserve scientific claims, citations, labels, results, and author metadata unless their modification is requested. Use the project's existing validation and report what actually ran.
- Upload only when requested: run `push`, review staged changes and outgoing commits, then use `push --confirm` after approval of that state. Respect existing approval; changed snapshots require renewed review.
- Keep credentials in Git's credential helper. Never put tokens in chat, files, URLs, or commits; never force-push.
<!-- overleaf-codex-workflow:end -->
