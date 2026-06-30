# Verification Before Completion

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Feedback item Done | Re-read of original verbatim + inspection of rendered artifact | Edited the source file the verbatim referenced |
| Deliverable ready | Opened the actual `.docx` / `.md` / page in the program the user will open it in | Markdown source looks right; structural checks pass |

## The rendered-artifact rule

For any change that affects user-facing output (briefs, reports, deliverables, UI, API responses), the verification target is the **rendered artifact the user sees**, not the source file you edited.

A structural check (regex against the markdown source) is necessary but not sufficient. python-docx may produce a structurally-valid file that renders as fragmented bullets in Word; an API may return a structurally-valid JSON whose presentation is broken in the consuming UI. Open the artifact in the consumer's tool before claiming the fix is in.

When closing a feedback-ledger item, this rule combines with `feedback-ledger-discipline.md` — re-read the original Verbatim, inspect the rendered artifact, then flip status.

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit/push/PR without verification
- Relying on partial verification
- ANY wording implying success without having run verification
- Closing a feedback item because you edited a file (vs. inspected the rendered output)
- Marking a deliverable ready because markdown source is clean (vs. opened the .docx)
