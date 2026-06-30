# Autonomous GLM Unstuck Rescue — Adaptive Placement

## Context

We just fixed the GLM rescue drift: pinned the 15 GLM unstuck agents in
`tig_allocate_fleet.py` (allocator's 15-min rebalancer no longer shuffles them off
the stuck lanes) and redistributed them across all 8 challenges. Deep
investigation of the production (VPS-canonical) code now confirms **the rescue is
already autonomous and working correctly**:

- **Mode assignment is autonomous + aggressive.** `tig_operator_scheduler.py` runs
  every 15 min (cron `4,19,34,49`), writes `/var/lib/tig-swarm/operator-state.json`,
  and agents read their mode at runtime (`run_loop.py:2575`). Verified live: GLM
  agents on stuck lanes get hard rescue modes — vector_search(240h)→`fresh_start`
  (reflect=30, fresh_start=32), hypergraph(168h)→`crossover` (reflect=21),
  knapsack(135h)→`fresh_start`, all driven by the `structural_breakthrough` recipe
  ("require new family/track mechanism"). The `creative_explorer` model trait does
  NOT starve rescue — challenge-state + recipe bumps dominate. **No scheduler/mode
  fix needed.**
- **Placement is stable** (pinned) but STATIC — my one-shot manual redistribution.
  This is the only remaining manual gap: if the stuck-ranking shifts (a lane
  newly stalls, a new challenge appears), the fleet does not auto-re-concentrate.

The plateaus persist (vector_search 240h, hypergraph 168h, knapsack 135h) because
breaking them is genuinely hard — opus/gpt-5.5 didn't break them either — NOT
because the rescue is mis-wired. The system is correctly forcing structural
breakthroughs.

**Goal:** close the last manual gap — make unstuck placement self-optimizing so no
human redistribution is ever required, while bounding transition dips.

## What I'll build

### 1. `scripts/tig_redistribute_unstuck.py` (new) — adaptive rescue placement
Mirrors the manual `redistribute_glm.py` logic already proven in this session, but
automated + conservative. Reads only existing data sources, no new infra:

- **Stuck-ranking source:** `/var/lib/tig-swarm/plateau-diagnosis.json`
  (`challenges[*].plateau_hours`) — already maintained by an existing cron (fresh
  timestamp observed).
- **Fleet source:** DB `agents` where `name LIKE 'zai-%glm52%'` (all 15; active
  ones produce, the 5 paused land on the worst lanes as correctly-placed reserves).
- **Algorithm:** sort the 8 challenges by `plateau_hours` desc; assign the 15 GLM
  agents round-robin from worst lane first so every lane gets ≥1 and the worst
  plateaus get 2–3. (Identical shape to the manual redistribution that's currently
  live and verified.)
- **Churn control:** compute the minimal diff vs current assignments; only move an
  agent when its target lane differs AND the move improves concentration; cap at
  `--max-moves N` (default 3) per run to bound transition dips. If the ranking
  hasn't shifted, 0 moves.
- **Apply:** update `agents.assigned_challenge` (DB) + each worktree
  `agent.config.json` (+ `tacit_knowledge` path) for changed agents only. Agents
  pick up the new lane via `setup.py sync` (`run_loop.py:1088 sync_challenge`) —
  **no `systemctl restart`, so no cold-build storm.**
- `--dry-run` prints proposed moves; default applies. Logs to
  `/var/log/tig-swarm/unstuck-redistribute.log` with post-run coverage per lane
  and an `[ALERT]` line if any active lane ends at 0 GLM agents.

### 2. Cron entry (every 6h)
```
0 */6 * * * cd /root/prometheus-early-beta && DATA_DIR=/var/lib/tig-swarm/server-data python3 scripts/tig_redistribute_unstuck.py --max-moves 3 >> /var/log/tig-swarm/unstuck-redistribute.log 2>&1
```
6h balances adaptivity vs transition cost. The allocator's 15-min pin still holds
between runs (it cannot undo a redistribution — the pin skips GLM agents in
`changes`).

### 3. Coexistence + safety
- The allocator pin (`_is_glm_unstuck_pin`, already deployed) and this job don't
  conflict: the pin stops the *allocator* from moving GLM agents; this job moves
  them *intentionally* via direct DB writes. Different cadences, no race.
- Job is idempotent and read-only on failure (validates JSON, wraps DB writes in a
  transaction, never `rm`s worktrees).

## What I will NOT change (and why)
- **Modes** — verified firing aggressively; no scheduler edit.
- **The 5 paused GLM agents** — your budget call; the job places them on the worst
  lane as reserves but does not start them.
- **GPU throughput / Vast spend** — confirmed out of scope. The
  `gpu_capacity_waits` on hypergraph/vector_search is the Vast spend-guard doing
  its job: **keep Vast GPU spend under $10/day**. It is intentional throttling,
  not a bug. Current config (`runtime.json` `vast_gpu_fallback.daily_budget_usd`)
  sits well under that ceiling, so we're compliant. (Separate note, not part of
  this plan: if you ever want those 2 lanes to benchmark faster, raising the
  budget toward the $10 ceiling would ease the waits — your call, money decision.)
- **Allocator pin / runtime.json / status_query** — already repointed to GLM this
  session.

## Files
- **New:** `scripts/tig_redistribute_unstuck.py` (VPS + local mirror).
- **Edit:** root `crontab` (add the 6h line). I'll show you the exact line; you
  confirm before it goes live (never-commit / destructive-commands rules).

## Verification (end-to-end)
1. `python3 scripts/tig_redistribute_unstuck.py --dry-run` → confirm it proposes
   concentrating on the current worst plateaus (vector_search, hypergraph,
   knapsack) and that **no active lane loses its only agent**.
2. Apply (no `--dry-run`), then confirm DB spread + that the next allocator dry-run
   (`tig_allocate_fleet.py --dry-run`) proposes **0 GLM moves** (pin still holds).
3. Confirm GLM experiments appear on the (re-)targeted lanes within ~30 min via
   sync — query `experiments` joined to `agents` by challenge, last 30 min.
4. Re-read `operator-state.json` for a moved GLM agent → confirm it picks up the
   new lane's plateau signal + rescue mode on the next scheduler tick (15 min).
5. Leave commit to you.
