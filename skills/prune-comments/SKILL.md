---
name: prune-comments
description: Sweep recently-changed source files and remove self-explanatory comments per the prune-self-explanatory-comments rule. Invoke after a chunk of work, or whenever the comment-prune-scan hook flags hits. Runs automatically per the rule — no need to ask the user.
---

# Prune Self-Explanatory Comments

Enforces `~/.claude/rules/prune-self-explanatory-comments.md` on demand. The rule
already fires automatically (the `comment-prune-scan.sh` PostToolUse hook flags hits
on every Edit/Write, and the rule says prune without asking). This skill is the
manual sweep when you want to clean a set of files in one pass.

## The test

Two gates — a comment must pass **both** to survive.

**Gate 1 — does it carry a *why*, *tradeoff*, *constraint*, or *gotcha*?**
No → delete it (it restates what the code already says).

**Gate 2 — is that reason non-obvious *and* not already stated where the reader will look?**
A "why" still gets deleted if its reason is already conveyed by a descriptive name, the
adjacent code, or a referenced spec / ticket / PR. A "why" that restates intent the reader
already has is noise, not signal — being a "why" does not grant immunity.

Survives both gates → keep it, but as **ONE line**, never a paragraph.

**The failed-comment rule:** if you can't say in one line what the comment is *for*, or a
reader would ask "what's the point of this?", it has already failed. Delete it, or rewrite it
to name the concrete gotcha. A cryptic guardrail comment is worse than none.

## Procedure

1. Find the changed files:
   ```bash
   git diff --name-only HEAD; git diff --name-only --staged
   ```
   Scope to source files (`.ts .tsx .js .jsx .py .go .rs .rb`), **including test files** —
   test comments bloat just as easily (verbose mock-rationale blocks, restated setup). Skip
   only fixtures and `.d.ts`. In tests, keep `describe`/`it` intent and genuinely non-obvious
   setup narration, but apply the same trim-to-one-line standard to *why*/constraint comments.
   Never strip a functional `eslint-disable` / `ts-expect-error` directive or its `--` reason.

2. Read each changed file's comments and classify:
   - **Delete** — restates the next line (`// Fetch the user` over `fetchUser()`),
     narrates history ("the 2026-05-18 incident…"), repeats a field name, or states a
     *why* that's already obvious from a descriptive name, the adjacent code, or a
     referenced spec / ticket (a redundant "why" is still noise). Example of the trap: a
     comment explaining that a field is sourced a certain way "so X stays in sync" when the
     field name and source already make that plain and the rationale lives in the design doc.
   - **Keep, trim to one line** — documents a non-obvious why / constraint / tradeoff /
     gotcha / security intent. If it's a paragraph, compress to the essential sentence.
   - **Keep as-is** — section dividers (`// ==== X ====`), JSDoc type/param docs,
     `env:`-style config notes, and intentional markers the rule exempts.

3. Apply the edits. Re-run typecheck/lint after (comment edits shouldn't break either,
   but the quality hook will run on each Edit anyway).

## Don't

- Strip JSDoc that documents params/returns/contracts.
- Remove `// why:` / TODO / FIXME / constraint comments just to hit zero comments —
  the goal is signal, not silence.
- Touch generated files or vendored code.

## Default behavior

Run this (or apply the rule inline) after every chunk of work, before reporting done.
Do not ask the user whether to prune — the rule already authorizes it.
