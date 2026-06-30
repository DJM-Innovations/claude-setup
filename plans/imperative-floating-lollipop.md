# Phase 2.3 — Auto multi-challenge fleet (per-agent challenge assignment)

## Context

The self-hosted TIG swarm server (VPS `64.177.112.129`, FastAPI+SQLite on `:8443`) currently runs the
**entire free fleet on one global challenge** via a singleton `config.active_challenge` row. Today that's
energy_arbitrage (best ~6.29M, climbing toward incumbent "titan"). The user wants the fleet to work **all
active TIG challenges concurrently and automatically** — no manual flipping, free agents spread across
challenges.

Key discovery: the server DB is **already keyed by `challenge`** (`experiments`, `best_history`,
`agent_bests`, `agent_challenge_state`, `challenge_configs` all have a `challenge` column). The *only* thing
forcing single-challenge is the global `active_challenge` switch that every agent reads. So this is an
**assignment** change, not a schema rewrite — and it makes "flipping" obsolete (flip = 100% on one challenge,
multi = split, EV-rotation = reallocate; all from one mechanism).

**Decisions (user):**
- **CPU challenges now, GPU via cloud later.** This VPS is CPU-only; 3 of 8 active challenges
  (hypergraph, neuralnet_optimizer, vector_search) are GPU and physically cannot run here. Scope = the
  **5 CPU challenges**: satisfiability, vehicle_routing, knapsack, job_scheduling, energy_arbitrage. GPU gets
  a deferred hook to the existing `scripts/c3_compute.py` cloud-GPU path.
- **Even split** of free agents across the active CPU challenges (~10 agents each across 5). Weight knob lives
  in runtime config so it can become weighted/EV-driven later (Phase 2.4).

**Invariants (unchanged):** free models only; CLI/paid agents stay paused until explicit enable; Opus stays
paused; **user commits manually** (leave changes staged on the VPS, nothing auto-committed).

---

## Approach (4 sub-phases + deferred GPU hook)

### 2.3a — Per-agent challenge assignment (the capability)
The core change. Reuses the existing per-challenge data layer.

- **DB** (`server/db.py`, `agents` table ~line 13): add nullable column
  `assigned_challenge TEXT DEFAULT NULL` via the existing idempotent `CREATE TABLE`/migration pattern. NULL =
  follow global `active_challenge` (backward compatible). Add helper
  `get_agent_assigned_challenge(conn, agent_id)`.
- **Server** (`server/server.py`):
  - `resolve_challenge(challenge, agent_id=None)` (~line 90): if `agent_id` given and has an
    `assigned_challenge`, return it; else fall back to global. This single function already feeds `/api/state`
    (line 658) and ~13 other endpoints, so per-agent routing propagates for free.
  - `/api/swarm_config` (~line 2074): accept optional `agent_id`; when present, return that agent's
    `assigned_challenge` as `active_challenge` and that challenge's `tracks` — so the agent's local cache gets
    *its* challenge.
  - Admin endpoint (extend existing `POST /api/swarm_config` admin path, ~line 2144) to set/clear
    `assigned_challenge` per agent (used by the allocator in 2.3c).
- **Agent sync** (`setup.py run_sync`, ~line 497): it already reads `agent.config.json`
  (`AGENT_CONFIG_PATH`, line 116) and GETs `/api/swarm_config`. Thread the worktree's `agent_id` onto that GET
  so `.swarm-cache.json` is written with the agent's assigned challenge + tracks. `benchmark.py` and
  `run_loop.py` already read challenge from `.swarm-cache.json` / `/api/state` — no change needed there once
  both sources agree.

### 2.3b — Generic per-challenge config seeding
Make the energy_arbitrage unblock reproducible for any challenge.

- Generalize `scripts/seed_energy_arbitrage_config.py` → `scripts/seed_challenge_config.py <challenge>`:
  - **Tracks: mechanizable** — read the canonical `track_keys` straight from the registry
    `server/challenges.py` (`CHALLENGES[<slug>].track_keys`, already in correct kv-string form), build the
    `{seed:test, <key>:2, ...}` tracks dict (×2 = 10 instances, clears the submission gate).
  - **Baseline: per-challenge file** — read `baselines/<slug>_baseline.rs`; assert `use super::*;` preamble +
    a feasibility marker; write `challenge_configs` (tracks, timeout from registry, scoring_direction,
    initial_algorithm_code). Restart `tig-dashboard` to clear the config cache.
- **Author + verify 4 CPU baselines** (the real work; energy_arbitrage already done):
  `satisfiability`, `vehicle_routing`, `knapsack`, `job_scheduling`. Each must be a *guaranteed-compiling,
  feasible* trivial policy (empty-set / zero-action / arbitrary-valid). **Verify each via the real benchmark
  path** (`scripts/benchmark.py` in a paused worktree, docker build) → must return `feasible: True`, not the
  infeasibility penalty. This is where the energy_arbitrage bugs hid (wrong preamble, infeasible greedy), so
  each baseline is preflighted before seeding.
- Ensure each CPU challenge's docker dev image is pulled (only energy_arbitrage is cached now); `benchmark.py`
  build path is already challenge-generic.

### 2.3c — Auto-allocator (even split)
- `scripts/tig_allocate_fleet.py`: read seeded CPU challenges (from `/api/swarm_config available_challenges`,
  filtered to non-GPU + has-initial-algorithm), read the active **free** agents, assign an **even split** →
  set `agents.assigned_challenge` (via the admin endpoint), then poke agents to resync (touch/restart so the
  next `sync` pulls the new challenge). Idempotent; weights read from `config/runtime.json` (default even).
- Preserve lineage: energy_arbitrage agents that stay assigned keep their trajectory; only reassigned agents
  switch.

### 2.3d — Challenge poller (detect + onboard, never flip)
- `/usr/local/bin/tig-mainnet-challenge-poller.sh` (cron, e.g. every ~2h at an off-minute): query TIG mainnet
  (`https://mainnet-api.tig.foundation/get-block` → `get-challenges?block_id=`, per `setup.py` `_mainnet_get`)
  for the active challenge set. For any **active CPU** challenge missing a `challenge_configs` row (and having
  a baseline), run the generic seeder (2.3b) and re-run the allocator (2.3c). Detection + onboarding only — it
  does **not** flip a global switch.
- **Fix the dead-Railway bug**: `/usr/local/bin/tig-challenge-watcher.sh` still has
  `BASE=https://prometheus-early-beta-production-2407.up.railway.app`; repoint to `http://localhost:8443` so
  the existing downstream auto-adapt (tacit/docker/rebalance) actually fires self-hosted.

### Deferred — GPU via cloud (Phase 2.4 hook, not built now)
- The allocator tags GPU challenges (`is_gpu=True`) for a future `c3_compute.py` cloud-GPU pool
  (`_select_docker_image` already handles `is_gpu` GPU images). No GPU work this phase.

---

## Critical files

- `server/db.py` — `agents` table migration (+`assigned_challenge`), `get_agent_assigned_challenge`.
- `server/server.py` — `resolve_challenge(agent_id=...)` (~L90), `/api/state` (~L658), `/api/swarm_config`
  GET+admin (~L2074/2144).
- `setup.py` — `run_sync` threads `agent_id` into the `/api/swarm_config` GET (~L497).
- `scripts/seed_challenge_config.py` (new, generalize `seed_energy_arbitrage_config.py`).
- `baselines/{satisfiability,vehicle_routing,knapsack,job_scheduling}_baseline.rs` (new, per-challenge,
  preflighted).
- `scripts/tig_allocate_fleet.py` (new); `config/runtime.json` (allocation weights).
- VPS: `/usr/local/bin/tig-mainnet-challenge-poller.sh` (new), `tig-challenge-watcher.sh` (URL fix), crontab.
- Registry reference (read-only source of track_keys): `server/challenges.py`.

## Verification (end-to-end, per challenge then fleet-wide)

1. **Per baseline:** seed challenge config → run `scripts/benchmark.py` in a paused worktree → assert
   `feasible: True` and a real (non-penalty) score before allocating any agent to it.
2. **Assignment:** set one test agent's `assigned_challenge`, confirm its `.swarm-cache.json` + `/api/state`
   both report that challenge (not the global), and it benchmarks/publishes to the right per-challenge tables.
3. **Allocator:** run it → query DB for the `assigned_challenge` distribution (≈ even across the 5 CPU
   challenges) → confirm each challenge's `experiments`/`best_history` start accumulating **feasible** scores
   and per-challenge leaderboards populate.
4. **Lineage + invariants:** energy_arbitrage agents that stayed keep climbing (no trajectory reset); re-run
   the free-only / opus-paused leak check (active providers ⊆ {clawrouter,cerebras,groq,github-models,
   sambanova,vercel-ai}, 0 CLI/paid/opus).
5. **Poller:** dry-run against TIG mainnet → confirm it lists active CPU challenges and would onboard a
   missing one (seed + allocate), without flipping.

## Risks / notes

- **Baseline authoring is the bulk + the risk** — 4 challenges of real Rust that must compile in the
  tig-challenges structure and be feasible; each verified via docker benchmark before seeding (no blind seeds).
- **Compute:** even split = ~10 agents/challenge on a box already at load ~30/8 cores; depth per challenge
  drops vs 50-on-one. Real depth on all needs more VPS boxes — flagged, not solved here.
- **Docker image pulls** for 4 more CPU challenges (disk + time).
- Nothing committed — changes land on the VPS staged; user commits.
