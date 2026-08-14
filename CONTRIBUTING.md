# Contributing

Contributions are welcome. Please keep the project focused on the Overleaf/Git/Codex synchronization lifecycle rather than general academic writing prompts.

Before opening a pull request:

```bash
bash tests/test.sh
```

Please preserve these invariants:

1. No force push.
2. No automatic destructive reset/rebase/merge/stash behavior.
3. No secret/token storage in tracked files.
4. Push remains a two-step review + confirmation operation.
5. Overleaf's synchronization target remains `master` unless Overleaf changes its documented Git behavior.
