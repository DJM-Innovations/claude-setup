# No Hardcoded Values

Hardcoded values that should be dynamic are a recurring source of silent bugs. They work perfectly on day 1 and fail silently after any upstream change — protocol governance, API version bumps, price updates, schema drift, dependency upgrades.

**The rule**: values that can change without your involvement must be read from a live source or a config file. Never inlined.

## What counts as "should be dynamic"

### Tier 1 — values owned by a remote system

Any value sourced from:
- An external API response (fees, thresholds, rate limits, schema versions)
- A smart contract read (addresses, owner, config state)
- A blockchain or network config (chain IDs, RPC URLs, block times)
- A third-party service (model names, pricing, endpoints)
- A governance-controlled protocol parameter

These MUST go through a client module with caching + fallback, not inlined as constants.

### Tier 2 — values you could reasonably want to change

Any value that:
- Is a threshold, limit, or coefficient chosen based on intuition or past data
- Is a schedule time, frequency, or polling interval
- Is a retry count, timeout, or rate limit
- Is a feature flag or mode switch
- Is a default user-visible parameter

These MUST go in a project config file (`config/runtime.json`, `config.yaml`, etc.) and be read via a typed accessor.

### Tier 3 — magic numbers with domain meaning

Numeric constants that represent something specific to the domain:
- Time periods (28-day cooldowns, 7-day windows, 30-second timeouts)
- Capital amounts, volumes, multipliers
- Percentage thresholds

MUST be named constants with explanatory comments, or ideally moved to config.

## What's allowed to be hardcoded

- Language / spec constants: `CALL=0`, `DELEGATECALL=1`, zero address `0x0...0`, HTTP status codes
- Math constants: `math.pi`, `e`, square root as `** 0.5`
- Internal enum values that are part of your own type system
- Fallback values INSIDE `except`/`catch` blocks that fire only when the dynamic source is unreachable (explicitly labeled as fallbacks)
- Test fixtures for reproducibility
- Comments, docstrings, documentation, rules, skills

## The litmus test

Before committing a literal value, ask:

> "If [external system] changes this value tomorrow, would my code silently use the wrong number?"

- **Yes** → make it dynamic (live lookup or config)
- **No** → inline is fine

Example: `CALL_OPERATION = 0` — this is defined by EIP / EVM; it will never change. Inlining is correct.
Example: `SUBMISSION_FEE_TIG = 250` — this is governance-controlled; it changed to 500 between spec and production. Must be dynamic.

## Enforcement

When writing new code:
1. For every numeric or string literal, ask the litmus question above
2. If the answer is "yes", refactor: add to config or to a client module, consume via accessor

When reviewing:
1. Scan the diff for literals
2. Flag any that pass the litmus test as blockers

When fixing a hardcoded bug:
1. Don't just update the hardcoded value; move it behind a dynamic accessor
2. Add a fallback path for when the dynamic source is unreachable
3. Write a test that verifies the dynamic read works

## Why this cannot be relaxed

Every hardcode is a shortcut. Each one seems harmless at write-time. The cost of a hardcoded-value bug is paid later: silent drift, silent economic loss, silent security issue. The cost of dynamic lookup is paid upfront — minutes of config wiring.

Prefer the upfront cost. Always.
