# Feedback Ledger Discipline

**Lesson learned from the Axon Air grant-research build (2026-05-15 → 05-17): 26 items were marked Done across two iterations, but a thorough re-read found 17 still-open sub-points hiding behind those Done flags. The pattern was the same every time — I changed code, ran a structural check, and flipped status without re-reading the original Verbatim or inspecting the rendered output.**

This rule prevents that pattern.

## The Iron Rule

```
A ledger item flips to Done only when ALL of these hold:

1. You have re-read the item's Verbatim field word-by-word in this session.
2. Every distinct sub-point in the Verbatim is addressed — not just the headline.
3. The rendered output (the artifact the user will see) has been inspected
   and the asked-for change is visibly present.
4. You have grepped the whole skill / repo for stale relics that the fix
   should have removed (old terminology, old data shape, old config keys).
```

If any of the four conditions is unmet → status stays Open or moves to In Progress, NOT Done.

## The "Verbatim sub-point parsing" check

User feedback is rarely one ask. A single Verbatim usually contains 2–5 distinct sub-points stitched together. Parse them out before claiming the item is closed.

**Example — AX-20 from the Axon Air build (the headline was "past-awards block is a regional pivot"):**

> "The 'Past awards to Fayetteville Police Department (AR, past 3 FYs) - 50 awards totaling 153,780,330 dollars' section is a USAspending recipient pivot matched on the region, not the agency: the line items are Arkansas Dept of Transportation, University of Arkansas, Division of Agriculture - none are the police department. The doc then tells the grant writer to 'use these to demonstrate the agency track record,' which would put false track-record claims in a federal application. Filter the pivot to the actual applicant agency, or relabel as area-wide context and remove the 'use to demonstrate track record' instruction. **'0 unique CFDAs' alongside '50 federal awards' is also internally inconsistent.**"

The Verbatim has FOUR sub-points:
1. Past-awards block is a regional pivot, not the agency
2. False "use as track record" instruction
3. **"0 unique CFDAs" alongside "50 federal awards" inconsistency**
4. (Implicit) recipient names must match before citing

A first pass fixed (1) and (2), and confidently marked AX-20 Done. Sub-point (3) — explicitly bolded in the Verbatim — remained for two iterations because I never re-read the Verbatim against the new output.

**The fix:** before any `status → Done`, copy the Verbatim into your working notes, split it into a numbered list of sub-asks, and confirm each one against the new output.

## The output-inspection rule

```
A code change is not a fix.
A test passing is not a fix.
A structural check passing is not a fix.

The fix is: the rendered artifact the user sees, contains the change.
```

For a brief / report / deliverable skill:
- Open the actual `.md` or `.docx` produced by the new code
- Read the section the feedback referenced
- Confirm with your eyes that the asked-for change is present

For a UI change:
- Open the page in a browser
- Click through the user flow

For an API change:
- Call the endpoint with the same payload the user saw
- Inspect the response

Skipping this step is how subtle defects survive: HTTP codes still leaking through, blank fields rendering "(?)" markers, "Default CFDAs (3)" still in SKILL.md after being removed from JSON, sales-voice subsections still in a "forwardable" section.

## The stale-relic grep

When a feedback item asks to **remove** something, the removal usually has more than one home. After deleting from the obvious file:

```bash
# grep the whole skill / project for the removed token
grep -rn "<the removed token>" <skill-dir> <related-dirs>
```

If hits remain → not Done. Examples of relics that survived a "removed" fix:
- `default_cfdas` deleted from JSON, but `Default CFDAs (3):` still in SKILL.md (AX-25, took 2 rounds)
- `priority family (DOJ/DHS/DOT)` removed from one code path, still leaking into relevance reasons (AX-25, same round)
- `top half` / `bottom half` removed from compose code, still in SKILL.md docs describing the brief structure (K, 2026-05-17)

## Audience-boundary check (for any multi-audience artifact)

When a deliverable is segmented by audience (e.g., "Part 1 for sales, Part 2 forwardable to client"), the boundary is the most common place to leak voice/content from one section to another. Before marking any "audience separation" item Done:

```bash
grep -n "<voice marker for audience A>" <Part 2 of the deliverable>
```

Example: the Axon Air brief was "split for grant writer forwarding" two rounds before I noticed that **every** alternative-funding-mechanism block in Part 2 had a `Conor's angle:` subsection — sales voice inside the forwardable section. The grep `grep "Conor's angle" <part 2>` would have caught it.

## Count-math reconciliation

When a deliverable surfaces a count ("11 eligible grants", "23 awards totaling $X") the count must match what's actually rendered downstream. Mismatched counts erode trust faster than any other defect.

```
After any change that affects what's rendered:
1. Note the count in the summary/header
2. Count the actual rendered items
3. Reconcile — if they don't match, either the count is computed wrong
   or items are being filtered between count-time and render-time
```

## When to escalate

If you find a "Done" item that's actually still open during a re-read:
- Do NOT silently re-fix and re-mark Done
- Surface the gap to the user with the Verbatim sub-point you missed
- Then fix and re-mark with a new commit hash

The reviewer (user) needs to see that the previous Done was premature — both for trust and so the lesson lands.

## What "thorough check" means in practice

When a user says "check the ledger thoroughly" or "do a deep dive" or "you're missing things":

1. Open the ledger file in full (not just the summary table)
2. For each Done item, read the full detail block including the **Verbatim** field
3. Split each Verbatim into sub-points
4. For each sub-point, open the rendered output and verify the change is present
5. Report findings BEFORE re-fixing — let the user see what was missed

Don't shortcut step 5. Re-fixing without first acknowledging what was missed reads as defensive; the user wants to see the analysis, not just the patch.

## The audit-script carveout trap

**A rule's audit script is a hypothesis. The moment you write a carveout inside it ("excluding X because it's a deliberate marker"), you've encoded a private judgment as a passing condition. That carveout is almost always the violation you're trying to detect.**

Recorded example — Axon Air AX-32 (Part 2 voice rule), 2026-05-17:

The AX-32 voice rule prohibits "addressee" in Part 2 of the brief. I wrote an audit script that grepped for `you / your / yours / the grant writer / Surfaced for breadth / ...`. Then I added this line:

```python
# Strip [GRANT WRITER: ...] brackets — they're deliberate addressee markers
part2_neutral = re.sub(r"\[GRANT WRITER:[^\]]+\]", "", part2)
```

The audit passed. I shipped. Three iterations on AX-32 alone, the audit passed each time, and the user re-read the brief and pointed out: *"Part 2 is still using third-person language."*

The carveout was wrong. The `[GRANT WRITER: ...]` brackets WERE the violation — they labeled the addressee. The whole AX-32 rule was "no addressee", and my audit script had exempted the addressee-labeled construct from the addressee check on the strength of my own private rationalization.

### How to detect this in your own audit

When writing or reviewing an audit script, look for any line that:

- Adds a `# excluded as deliberate ...` / `# carveout for ...` / `# not counted because ...` comment
- Strips, filters, or rewrites a substring of the audited text *before* checking
- Uses a regex character class or negative lookahead that excludes a specific construct
- Has any prose comment justifying why a construct is exempt from the check

Every such carveout is a hypothesis. **The carveout passes the check only if the user confirms the exemption.** If the user hasn't seen the carveout, it doesn't exist — surface it before the audit runs.

### How to fix it

The first time you find yourself writing a carveout, stop. Two paths:

1. **Audit the construct anyway**, then surface the hits to the user and let *them* decide if those hits are acceptable. The user's call lives on the record (in the ledger, the commit, or the surface), not in your private regex.
2. **Re-read the rule's verbatim** to confirm the carveout isn't actually a re-interpretation of the rule. If the rule says "no addressee" and your carveout exempts addressee-labeled constructs, the carveout *changes the rule*. Changing the rule is a user decision, not an audit-author decision.

### Lineage and why this is a feedback-ledger discipline rule

This trap is a sub-case of the meta-rule above ("don't trust your own Done"). The pre-flip checklist tells you to verify rendered output against the original verbatim. But if your verification script has a self-justified carveout, you're verifying a weakened rule — and the user will see what your script missed. The carveout-trap section above is here so the next time the impulse fires ("I'll just exclude this one construct because it's deliberate"), the rule fires back.

---

## Why this rule exists

The Axon Air grant-research build burned three review rounds (and Daniel's patience) because each round I trusted my own "Done" flags. Each round Daniel pushed back, I did a deeper pass, and found more items hidden under those flags. By the third round there were 17 unresolved sub-points across 7 items I'd previously marked complete.

A fourth round added the carveout-trap dimension above: the audit script for AX-32 passed because I had written a private exception into it. The exception was the violation. The cost of the discipline above (a few extra minutes per item, plus a moment of self-suspicion when writing exceptions into audits) is much less than the cost of four review rounds that all started with the user saying "you missed things again."
