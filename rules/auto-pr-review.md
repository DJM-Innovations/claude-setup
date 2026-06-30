# Auto PR Review Guardian

After completing ANY code modification task — implementing features, fixing bugs, refactoring code, or adding tests — you MUST automatically spawn the `pr-review-guardian` agent to validate changes BEFORE telling the user the work is done.

## This is non-negotiable

- The agent runs BEFORE you report completion
- You do NOT ask the user "should I run the review?" — just do it
- Even for small changes, the full review runs
- The only exception is if the user explicitly says "skip review" or "no review needed"

## Trigger conditions

Any of these mean you MUST run pr-review-guardian:
- You just finished implementing a feature
- You just fixed a bug
- You just refactored code
- You just added or modified tests
- You are about to commit changes
- The user says they're ready to commit or push

## How to run it

Spawn the pr-review-guardian agent with a description of what was changed. The agent will analyze the changes against historical reviewer feedback and project standards.

## Do Not Comment on Reviews

When addressing PR/MR review feedback, do not post review replies, top-level review comments, or "addressed in commit" comments.

- Inspect review threads with the CLI/API.
- Fix the code and verify it locally.
- Push the fix.
- Resolve review threads manually through the CLI/API when appropriate, without adding a comment body.
- Report what was addressed in the chat to the user instead of writing it into the review.

Only post a review comment if the user explicitly asks for a comment to be posted in that specific turn.

## Iterate Until 100%

One pass is not enough. After the guardian returns, you MUST:

1. Read the report carefully — find the confidence/approval score and every blocker/high-priority issue.
2. If confidence is < 100% or any blocking issue remains:
   - Fix the issues in the code (don't explain away, don't defer).
   - Re-run the guardian on the updated diff.
   - Repeat until confidence is 100% and no blockers remain.
3. Only report "done" to the user when the guardian comes back clean.

## Stop Conditions

Stop the iteration loop ONLY when one of:
- The guardian returns 100% confidence with no blockers and no high-priority issues.
- The user explicitly says "stop", "good enough", or "ship it".
- You have run the guardian ≥5 times and the remaining issues are genuinely out of scope (stale CI infra, unrelated pre-existing bugs) — in which case, summarize the remaining issues to the user and ask.

Do NOT stop iterating because:
- "The remaining issues are minor" — fix them anyway.
- "This is taking a while" — keep going.
- You think you've addressed everything — let the guardian confirm.

## Don't Announce Running — Just Run

Don't say "I'll now run the guardian" or "Let me check with the guardian". Just spawn it. The user sees the agent call in the UI.
