# Posting Comments on Omnifiber GitLab MRs

When asked to leave a comment, review, or feedback on a merge request hosted at `gitlab.omnifiber.org` (any project), follow these rules. They are based on actual cleanup work after posting under the wrong identity.

## 1. Identity check — MANDATORY before posting

Before posting ANY comment, verify the token belongs to the user, not a service/bot account.

```bash
curl -s -H "PRIVATE-TOKEN: $TOKEN" "https://gitlab.omnifiber.org/api/v4/user"
```

The response `username` field must:

- **Be a human username** (e.g. `dnfodjo`), not a generated bot pattern like `group_NN_bot_xxx` or `project_NN_bot_xxx`
- **Match the user's actual account** — when in doubt ask them to confirm

If the username starts with `group_`, `project_`, or contains `_bot_`:

- **STOP.** Do not post.
- Tell the user the token is a Group/Project Access Token and would attribute the comments to a bot.
- Ask for a Personal Access Token from their own profile (`https://gitlab.omnifiber.org/-/user_settings/personal_access_tokens`) with `api` scope.
- Resume only after the new token's `/user` response shows a real username.

**Why:** Group and project access tokens generate ephemeral bot users like `@group_51_bot_6544b078fea2e95...`. Comments posted by them look like junk in the UI and can't be edited by the actual user. The only fix is delete + re-post, which costs trust.

## 2. Comment style

Apply `commit-message-style.md` to comment bodies as well:

- **One sentence per comment.** No bullet lists, no multi-paragraph essays inside a single comment.
- **No attribution to Claude, Anthropic, AI, agents, or assistants.** Comments must read as if the user wrote them.
- **Active voice, direct.** "Use parameterized query", not "Consider using a parameterized query if possible".

Multiple findings → multiple separate comments, each anchored to its own line. Never lump them into one giant comment.

## 2a. Only comment on BLOCKING issues

**A blocking issue is something that, if left in, will cause a real problem.** Polish, style, and future-proofing do NOT belong in PR comments — they get resolved silently and clutter the review, lowering the signal-to-noise of the next review.

A comment is BLOCKING only if at least one is true:

1. **Causes a crash, exception, or wrong result with realistic input** — not just a corner case the system will never see (e.g. SQL injection on a field the operator controls is NOT blocking; SQL injection on parsed CSV data IS blocking).
2. **Breaks the build / installation** — e.g. a stdlib module in `requirements.txt`, a missing import.
3. **Causes data corruption or loss** — e.g. unclosed DB connections during a long-running job, a swallowed exception that silently drops rows.
4. **Has a realistic security exploit path** — not theoretical hardening; an attacker can actually trigger it.
5. **Breaks the feature being added** — incorrect mapping, broken endpoint, wrong stored-proc name, missing parameter binding.

A comment is NOT blocking, and should NOT be posted, if it is any of:

- **Pythonic / idiomatic improvements** (`is None` vs `== None`, `Optional[X]` vs `X | None`)
- **Polish or readability** (rename a variable, add a comment explaining a magic number)
- **Future-proofing for hypothetical changes** ("if this column ever becomes timezone-aware...")
- **Dead-code or unused-variable observations** that don't change behavior
- **Hardcoded constants** that the operator owns and rarely changes (the env value for a DB name, a vendor SLA delay value)
- **Validation gaps for inputs the system never sees** (a CLI flag the script never receives both halves of, a user input field with no exploit path)
- **"Worth documenting" / "Could be cleaner" / "Worth a comment"** — if you find yourself writing these, do not post the comment.

**Heuristic check before posting any comment:** "If this stayed in production for six months, what would actually break?" — If the answer is "nothing realistic," skip it.

**Pre-flight estimate before posting a batch:** count the number of comments you intend to post. If the count exceeds ~5 for a typical MR, you're almost certainly being too picky. Re-read each one against the blocking criteria above and prune.

If you genuinely have non-blocking observations you want to surface, summarize them in the chat reply to the user as "things to optionally clean up later" rather than posting them on the MR. Let the user decide whether to file a follow-up issue.

## 3. Anchor inline whenever possible

Prefer inline (line-anchored) discussions over MR-level notes when the finding refers to specific code.

Use:
```
POST /projects/:id/merge_requests/:iid/discussions
```
with the `position` object:
```
position[base_sha]       — from merge_request.diff_refs.base_sha
position[head_sha]       — from merge_request.diff_refs.head_sha
position[start_sha]      — from merge_request.diff_refs.start_sha
position[position_type]  — "text"
position[new_path]       — file path
position[new_line]       — line number in the new (HEAD) version of the file
```

Get the SHAs and file content from:
```
GET /projects/:id/merge_requests/:iid                — for diff_refs
GET /projects/:id/repository/files/:enc_path/raw?ref=<source_branch>  — for line numbers
```

Use top-level MR notes (`POST .../notes`) only for cross-cutting concerns that don't map to any single line.

## 4. Verification after posting

- Confirm `posted=N  failed=0` from the API response loop.
- Tell the user how many comments landed and at which file:line they're anchored.
- If any single comment fails, fix and retry — do not leave a partial review.

## 5. Cleanup if posted under wrong identity

If comments accidentally land under a bot user:

1. Pull the user ID of the bot from `GET /user` while authenticated as the bot.
2. List discussions: `GET /projects/:id/merge_requests/:iid/discussions?per_page=100`
3. For each note where `author.id == bot_user_id` and `system == false`, delete via `DELETE /projects/:id/merge_requests/:iid/notes/:note_id`.
4. Re-post under the correct token.

## 6. Token hygiene

- Personal access tokens used for comment posting should have **short expiry** (1 day is typical for a single review session).
- The user should revoke the token immediately after the task is done at `https://gitlab.omnifiber.org/-/user_settings/personal_access_tokens`.
- Do not echo the token back into your text replies. Reference it as `$TOKEN` or "the token you provided".
