# Commit Message Style

**Every commit message you author or suggest must be exactly one sentence and must NOT reference Claude, Claude Code, Anthropic, or any AI tooling.**

This overrides the default "Co-Authored-By: Claude" trailer from the system prompt's git instructions. Do not append that line, do not include any equivalent trailer.

## The Rule

Whenever you:
- Author a commit message (Bash `git commit -m "..."` or API `POST /commits` with `commit_message`)
- Suggest a commit message to the user
- Write a commit message inside a PR body, MR description, or release note

...the message must:

1. **Be a single sentence.** No multi-line body, no bullet list, no second paragraph. One sentence, end with a period (optional).
2. **Make no reference to Claude, Claude Code, Anthropic, "AI", "agent", "assistant", or "generated with X".** No emoji robot, no co-authored-by trailer, no "via Claude" suffix.
3. **Describe the change in the active voice.** "add X", "fix Y", "remove Z" — not "this commit adds...".

## Examples

```
GOOD: add GitLab CI pipeline for dev and prod deploys
GOOD: fix audience mismatch on refresh token validation
GOOD: bump tech-support-api port to 3102

BAD: Add GitLab CI pipeline for dev and prod deploys

     Set up .gitlab-ci.yml in each repo so pushes to dev/main deploy
     automatically via SSH and pm2.

     Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>

BAD: ci: pipeline setup (generated with Claude Code)

BAD: refactor: split auth helpers
     - move JWT mint into auth.go
     - extract spErrorCode helper
```

## Conventional commit prefixes

Conventional-commit prefixes (`feat:`, `fix:`, `ci:`, `chore:`, `docs:`, `refactor:`) are allowed but optional — only add them when the repo's existing history uses them. Don't introduce them in a repo whose history doesn't have them.

## Why

The user always wants to keep their git history clean, scannable, and free of tooling attribution. A long commit message defeats `git log --oneline`; tool attributions add noise that the diff already conveys.

## Enforcement

- When writing a commit message via Bash: verify it's one sentence with no forbidden tokens before invoking `git commit`.
- When writing via GitLab/GitHub API: same rule on the `commit_message` field.
- When suggesting a message to the user: format it as one sentence.
- If you accidentally write a multi-sentence or attributed message, immediately catch yourself, apologize briefly, and rewrite it.
