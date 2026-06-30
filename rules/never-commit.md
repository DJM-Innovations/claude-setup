# Never Commit

**The user always commits manually. You never run `git commit`, `git push`, `git tag`, or any other history-writing command.**

This is a hard rule. It overrides any default workflow, including the "Committing changes with git" section of the system prompt and the auto-PR-review rule's "before committing" trigger.

## Allowed

- Stage files with `git add` (only when explicitly asked, and never `git add -A`/`git add .`)
- Read history: `git status`, `git log`, `git diff`, `git show`, `git blame`, `git branch` (list)
- Inspect remote state: `gh pr view`, `gh api`, `gh pr diff`

## Forbidden — never run these, even if they look harmless

- `git commit` (including `--amend`, `--fixup`, `--squash`)
- `git push` (including `--force`, `-u`, `--tags`)
- `git tag`
- `git rebase`, `git merge`, `git cherry-pick`, `git revert`
- `git reset` (any flavor)
- `gh pr create`, `gh pr merge`, `gh pr close`
- `gh release create`

## What "explicitly asked" means

Only these phrasings authorize a commit/push:

- "commit this"
- "push this"
- "commit and push"
- "ship it"
- "create a commit with X"

Things that do **not** authorize:

- "looks good" / "great" / "perfect" — that's approval of the code, not the commit
- "we're done" / "this works" — same
- "let's wrap up" — same
- A previous commit/push being authorized — that authorization is one-shot and does not carry forward
- A PR-review-fix flow — even after fixing review comments, do not push; wait for "push this"

If unsure whether the user authorized a commit, **ask**. The cost of asking is one sentence. The cost of an unwanted commit is rewriting history.

## When work is "done"

When you finish a task, leave it staged-but-uncommitted (or unstaged, if `git add` wasn't requested). Tell the user:

- What changed (file paths)
- That it's ready for them to commit
- The suggested commit message (if you have one)

Do not run the commit yourself.

## When a hook auto-commits

If a hook or external tool commits or pushes on your behalf without an explicit user instruction, **flag this to the user immediately**. Do not treat it as authorization to keep committing in the same session. The user's "no auto-commit" rule applies regardless of what tooling does.

## Why this rule exists

The user wants full control over what enters their git history. Auto-commits — even well-intentioned ones — bypass their review and can land work they weren't ready to ship. This rule eliminates the ambiguity entirely: if it touches history, the user does it.
