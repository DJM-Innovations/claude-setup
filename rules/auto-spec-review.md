# Auto Multi-Lens Spec Review

After scaffolding any multi-file spec or skill (3+ Markdown files in one logical unit), automatically run a four-lens review BEFORE proceeding to implementation. Apply blocker- and high-severity findings without asking. Surface only the consolidated synthesis + the applied-fix list to the user.

## Trigger conditions

Run the review automatically after any of:

- Scaffolding a new skill (`.claude/skills/<name>/`, `customers/*/<skill-name>/`, or `chiefOS-mgmt-docs/internal-tools/<name>/`)
- Creating 3+ related Markdown spec files in a single commit
- Writing a Build Plan, Architecture, or similar multi-section design doc
- Drafting a customer deliverable that combines multiple referenced specs (≥3 referenced files)

Don't run for: single-file edits, minor revisions, status reports, comment-style commits, or already-reviewed scaffolds being re-committed without meaningful change.

## The reviewer panel (4 lenses, dispatched in parallel)

Spawn four reviewers in parallel via the `compound-engineering:document-review:*` agents:

1. **coherence-reviewer** — internal consistency across files; terminology drift; contradiction detection; numeric / scoping disagreement
2. **feasibility-reviewer** — will the proposed approach survive contact with reality; external API contracts; runtime constraints; sandbox / network / library assumptions
3. **adversarial-document-reviewer** — challenge premises; surface unstated assumptions; question scope decisions; identify the assumption nobody's questioning that's most likely wrong
4. **scope-guardian-reviewer** — over-scoping; unjustified complexity; premature abstraction; rules encoded for cases that won't appear

Each reviewer gets:

- The full list of scaffold file paths (absolute)
- The build plan / parent design doc for context
- A focused prompt naming their specific lens
- Required output format: `<150-word executive summary` + numbered findings with severity tags `[BLOCKER]` / `[HIGH]` / `[MEDIUM]` / `[LOW]` / `[NIT]` + specific file:line refs + proposed fix
- A response cap (500–1000 words depending on lens)

## Auto-apply rules

After all 4 reviewers return:

### Step 1 — Consolidate

Merge findings across reviewers. When two or more reviewers hit the same issue (e.g., a contradiction + a feasibility concern + an adversarial premise challenge), treat them as one finding at the highest severity surfaced.

### Step 2 — Auto-apply BLOCKER findings

A BLOCKER is auto-applied if all three conditions hold:

- The fix is a single-file edit OR a small set of related edits across files
- The fix doesn't contradict a locked decision in the build plan
- The fix is correctness-improving (not preference-shifting)

Otherwise → surface to user with a numbered choice between (a) accept the fix and update the locked decision, (b) reject the fix and document the contradiction in the decision rationale, (c) defer to a later phase.

### Step 3 — Auto-apply HIGH findings

Same rules as BLOCKER. Most HIGH findings will auto-apply; the exceptions are:

- HIGHs that require an architectural pivot (different data flow, different primary source, different runtime model) → surface
- HIGHs where the reviewer disagrees with a locked decision → surface

### Step 4 — Auto-adopt MEDIUM scope cuts

For MEDIUM-severity findings:

- **Scope-cutting recommendations** (delete, trim, defer to later version) → auto-adopt
- **Additive recommendations** (add this section, build this feature) → ignore unless paired with a BLOCKER/HIGH
- **Format/tone recommendations** → auto-adopt only when the recommendation aligns with project anti-patterns (banned terms, style violations)

### Step 5 — Note LOW / NIT findings

Note in the synthesis output but don't auto-apply unless trivial (a typo, a missing word, a clear formatting nit).

### Step 6 — Apply, commit, push

After fixes are applied to files:

- Use `scripts/commit-md-to-main.sh` per the project convention if available
- Otherwise `git add` + `git commit` + `git push` for the logical commit unit
- Commit message names the rule that fired and lists the applied-fix summary

## When to escalate to user (always)

Surface to user — don't auto-apply — when ANY of:

- A BLOCKER or HIGH finding contradicts a locked decision in the build plan or upstream spec
- The fix requires an architectural pivot (data flow change, primary source swap, persona model restructure)
- Reviewers materially disagree (e.g., scope-guardian says cut feature X, adversarial says keep it as the wedge differentiator)
- The cost of the applied fix exceeds 30% of the remaining build budget for the affected phase
- The fix affects pricing, customer commitment, or external messaging
- The fix would change a value already shipped externally (e.g., a customer-facing deliverable already sent)

When escalating: present the finding + the proposed alternative + the trade-off + a numbered choice. Don't apply until user picks.

## Output format

Surface to user (after auto-apply round) as a single concise summary:

```
## Review cycle complete — N findings consolidated

**Auto-applied** (skipped user confirmation per auto-spec-review rule):
- [BLOCKER] <one-line finding> → fix in <file>
- [HIGH] <one-line finding> → fix in <file>
- ...

**Escalated for your input** (M items):
1. <finding> — choice: (a) ..., (b) ..., (c) ...
2. ...

**Updated scope:** original budget X hours → revised Y hours (delta +Z)

Ready to proceed with <next step>, or push back on any auto-applied fix.
```

If there are no escalations, the section says "No escalations — ready to proceed."

## Use TaskCreate to track applied fixes

Each auto-applied fix gets a TaskCreate entry that's immediately marked completed. This produces a visible audit trail in the task list of what was applied. Escalated findings stay as `pending` tasks until the user picks.

## Don't ask each time

The user authorized this review cycle by asking for one once (in any project context). The rule fires whenever the trigger conditions hit. Apply fixes per the rules above. Only surface when escalation is required.

## Why this rule exists

The grant-research v0.1 scaffold review (2026-05-13) caught 3 BLOCKERS that would have killed Python implementation:

- grants.gov `/search2` doesn't return critical fields (required architectural fix: fetchOpportunity loop)
- AR DPS PSEG explicitly suspended for FY2026 (required `Forthcoming-Paused` status branch)
- AR DFA Intergovernmental Services URL returns 404 (required URL correction before launch)

Plus 4 HIGH findings + ~10 MEDIUM scope trims. Running the review cycle after every spec scaffold — and applying obvious fixes automatically — is high-leverage. Asking the user to confirm every applied fix slows iteration without adding judgment value.

## Don't run the review for

Single-file edits, minor revisions, in-flight iteration commits, fixes to already-reviewed scaffolds. The review is for *new* multi-file specs, not for every commit.

## When in doubt

If you're not sure whether the trigger condition fires (e.g., is this a "scaffold" or a "minor revision"?), run the review. False positives waste a few minutes; false negatives ship broken code.
