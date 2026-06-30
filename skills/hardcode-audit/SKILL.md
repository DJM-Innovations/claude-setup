---
name: hardcode-audit
description: Use before claiming a code change is complete. Scans changed files for hardcoded values that should be dynamic — external API constants, contract addresses, URLs, tunables, schedule times, magic numbers with domain meaning. Language-agnostic. Outputs offenders with suggested fixes.
---

# Hardcode Audit

Scans code for values that should come from a live source or config file but are inlined instead.

## When to run

- Before declaring a code change complete
- Before opening a PR
- When reviewing someone else's code
- After a bug caused by stale data turned out to be a hardcoded value

## How to run

Identify the files changed in the current edit. For each file, scan for the patterns below. For each match that is NOT in the acceptable-hardcodes list, produce a finding.

### Pattern 1 — External API / contract addresses

```bash
grep -nE '0x[a-fA-F0-9]{40}' <file>
```

**Rule**: any on-chain address that isn't the zero address or a clearly-named constant in a test fixture. Must come from config or a chain client.

### Pattern 2 — URLs for remote services

```bash
grep -nE '"https?://[^"]+"' <file>
```

**Rule**: production URLs should come from env or config. Exception: well-known CDN URLs for non-critical assets (e.g., font CDN), documentation links in comments.

### Pattern 3 — Magic numbers in economic / protocol code

```bash
grep -nE '\b(10|25|50|100|250|500|1000|10000|100000)\s*[\*\+\-\/\;,\)]' <file>
```

**Rule**: numbers like these in code that calculates fees, thresholds, rewards, or limits are almost always tunables that should move to config. Skip matches in test files, in comments, or inside array indices / loop bounds.

### Pattern 4 — Timeouts and retry counts

```bash
grep -nE 'timeout\s*=\s*[0-9]+|retries\s*=\s*[0-9]+|max_attempts\s*=\s*[0-9]+|sleep\s*\(\s*[0-9]+\s*\)' <file>
```

**Rule**: these should either be config values or clearly-justified internal operational constants.

### Pattern 5 — Schedule times / cron literals

```bash
grep -nE 'schedule\.every.*\.at\("[0-9]+:[0-9]+"\)|\*\s+\*\s+\*\s+\*\s+\*' <file>
```

**Rule**: schedule times and cron expressions should come from a schedule config, not be inlined in scheduler setup.

### Pattern 6 — Model / SDK version strings

```bash
grep -nE '"(claude|gpt|gemini|deepseek|kimi|llama|minimax)-[a-z0-9.-]+"' <file>
```

**Rule**: model IDs should come from a model config file. They change frequently; a config file is a single point of update.

### Pattern 7 — Docker image tags with explicit versions

```bash
grep -nE 'runtime|api|service|app:[0-9]+\.[0-9]+\.[0-9]+' <file>
```

**Rule**: pinned image tags outside of explicit config should be detected from `.env`, Cargo.toml, package.json, or similar sources of truth.

### Pattern 8 — Duplicated constants across files

```bash
# Find numeric constants used in more than 2 files:
grep -rnE 'CONSTANT_NAME\s*=\s*[0-9]' <changed-files>
```

**Rule**: if the same value is inlined in two or more files, it must be centralized.

## Acceptable hardcodes (no finding required)

- EIP/EVM/language spec constants: `0`, `1`, `0x0...0`, HTTP status codes
- Mathematical constants: `math.pi`, `** 0.5`
- Internal enum values defined by your own type system
- Fallback values inside `except`/`catch` blocks that only fire when the dynamic source is unreachable (explicit "defensive default")
- Test fixtures
- Documentation content inside string literals

## Output format

For each finding:

```
<file>:<line>  <pattern-category>
  code: <the offending line>
  suggestion: <concrete replacement>
  why it matters: <one-line explanation of what could break>
```

Example:

```
src/payments.py:42  external-constant
  code: MAX_FEE_USD = 100
  suggestion: move to config/payments.json, read via config.get("payments.max_fee_usd")
  why it matters: max fee is a business policy that changes; inlining causes update friction and stale values in deployed code

src/scheduler.py:88  schedule-literal
  code: schedule.every().day.at("09:00").do(daily_report)
  suggestion: read from config/schedule.json
  why it matters: deployment across timezones or schedule tuning becomes a code change, not a config change
```

## Completion gate

Audit passes when:
- Every finding is either fixed (moved to dynamic source) or explicitly classified as acceptable with a one-line justification
- No findings sit in "ignored" state

This is the same discipline as `verification-before-completion`: evidence required, not vibes.
