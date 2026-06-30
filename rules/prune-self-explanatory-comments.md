# Prune Self-Explanatory Comments

When adding, editing, or reviewing code, **do not leave self-explanatory comments behind**. Apply this automatically — the user should never have to ask.

## The Rule

A comment must explain *why*, *constraints*, or *non-obvious context*. If it merely restates *what the code does*, delete it.

## Remove These

```typescript
// Fetch the user                    ← method name says it
const user = await fetchUser(id)

// Loop over items                   ← the for-of says it
for (const item of items) {}

// Check if enabled                  ← the if says it
if (config.enabled) {}

// Insert into database              ← insertX() says it
await db.insertX(payload)

// Encrypt headers                   ← encrypt() says it
const encrypted = encrypt(headers)

{/* Header */}                       ← the element below is the header
<Header />

{/* Proxy URL */}                    ← the variable `url` + context says it
{url && <div>{url}</div>}

// ============ Helpers ============
// (keep these — section dividers aid navigation in long files)
```

## Keep These

```typescript
// Fallback: some clients send raw JSON instead of base64    ← documents WHY
try { JSON.parse(atob(h)) } catch { JSON.parse(h) }

// KV is eventually consistent; may exceed by small margin   ← flags tradeoff
await kv.put(key, String(count + 1), { expirationTtl: 120 })

// Render-time pattern; avoids setState-in-effect lint rule  ← documents pattern choice
if (endpoint && prev.hasChanged) { setState(...) }

// Hardcoded to avoid viem dep in Edge runtime               ← documents constraint
const USDC = { "base": "0x..." }

// Defense-in-depth SSRF check                               ← documents security intent
if (!isSafeHostname(url)) throw new Error("SSRF_BLOCKED")
```

## Heuristic

Ask: **"If I deleted this comment, would a reader still understand the code?"**

- **Yes** → delete the comment
- **No, they'd miss a *why*, *tradeoff*, *constraint*, or *gotcha*** → keep it

**The redundant-why trap:** being a "why" does not grant immunity. Delete a "why" when its
reason is already conveyed by a descriptive name, the adjacent code, or a referenced spec /
ticket / PR — a "why" that restates intent the reader already has is still noise. And if a
reader would ask "what's the point of this comment?", it has failed: delete it, or rewrite it
to name the concrete gotcha. A cryptic guardrail comment is worse than none.

## Enforcement

- When writing new code: don't author comments that merely restate the code.
- When editing existing code: if a diff touches a block with self-explanatory comments, prune them in the same edit.
- When reviewing (PR guardian, code-reviewer): flag them as a required fix before merge.
- Do not ask the user whether to prune — just do it. Only leave a comment that passes the heuristic above.

## Section Dividers Are Fine

`// ============ Section Name ============` style dividers in long files are navigation aids, not self-explanatory comments. Keep them.

## JSDoc / TSDoc

Type-level JSDoc that documents parameters, return types, or contracts is NOT a self-explanatory comment. Keep it.
