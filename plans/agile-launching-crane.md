# Plan: GPU challenges via C3 + join the foundation swarm (with auto-failover) + port the 9 public commits

## Context

The TIG foundation publishes the upstream `tig-foundation/prometheus-early-beta`
(our `origin`). It runs a separate public swarm on **one GPU challenge** at its own
Railway URL, and handed us a **C3 ("cthree") cloud-GPU key** that can drive GPU
benchmarking from our CPU-only VPS. The user wants four things, with "prioritize my
swarm", "nothing should break", and "all automatically" as hard constraints:

1. **Enable all 3 GPU challenges in our own swarm** (`hypergraph`,
   `neuralnet_optimizer`, `vector_search`) using C3 for the GPU compute — **FULL**
   staffing (user's choice, accepting the metered C3 cost; we still add a spend
   guardrail because the key is revocable).
2. **Send 2-3 flat-rate agentic-CLI agents to the foundation's swarm** (its Railway
   URL + creds) to learn/contribute — without diverting our paid/free agents.
3. **Automatic failover:** the foundation swarm can go offline at any time; when it
   does, those detached agents must **return to our own swarm automatically** and
   keep producing — then rejoin the foundation when it recovers. Zero intervention.
4. **Bring-back:** periodically seed our own GPU-challenge baselines from the
   **foundation's best-adopted GPU algorithm** (reuse the Task #56 refresh-baselines
   machinery), so their learnings land on our server.
5. **Deep-dive + selectively port** improvements from the 9 public commits we're
   behind on.

### Verified ground truth (firsthand this session)

- **VPS = `261caae`, 36 ahead / 9 behind `origin/main`, off shared base `196d9a5`.**
  The VPS's 36 commits and the foundation's 9 are **siblings** — this is a *selective
  port*, never a `git merge`/blind `scp` (see `.claude/rules/tig-deploy-sync-check.md`).
- VPS **already independently has**: multi-file `algorithm_files` (39 refs in
  `server/db.py`, from Task #56), the GPU challenge **source dirs** vendored under
  `src/{hypergraph,neuralnet_optimizer,vector_search}`, and a **real** `compute=c3`
  path in `scripts/run_loop.py` (branch at L662, c3 CLI presence check L1466-1468,
  `--c3-api-key` defaulting to `C3_API_KEY` env at L1226-1228, `--hardware/--c3-time/
  --c3-provider` args, per-agent `c3_provider` fallback at L1433).
- VPS is **MISSING** only `server/tiers.py` and `scripts/list_models.py` from the 9.
- **GPU challenges are NOT live**: `challenge_configs` has exactly 5 CPU rows
  (energy_arbitrage, job_scheduling, knapsack, satisfiability, vehicle_routing); its
  cols are `challenge, tracks, timeout, scoring_direction, initial_algorithm_code,
  initial_kernel_code, strategy_tags, initial_algorithm_files`. The 3 GPU challenges
  have no config rows → not active.
- **Multi-swarm is already per-agent** in `run_loop.py` (resolves `server_url`/
  `username`/`swarm_password` from agent config), BUT `scripts/run_fleet.py` currently
  materializes only the **top-level** triple onto every agent (L296-301) — so a
  per-agent override path is needed to point a few agents elsewhere.
- `fleet.config.json`: 165 agents; top-level keys `server_url, username,
  swarm_password, agents, agent_count, active_challenge, challenge`; agent entries
  carry `api_base, api_key_env, model, name, provider, tacit_knowledge` (no per-agent
  `server_url` today).

### The 9 public commits — deep-dive verdict (what's worth porting)

| Commit / file | Value | Action |
|---|---|---|
| GPU seeds+kernels `initial_algorithms/{hypergraph,neuralnet_optimizer,vector_search}/seeds/*.{rs,cu}` | **HIGH** — these *are* the initial algo/kernel for the GPU configs | Port → use as GPU baselines (Workstream B) |
| `545654a` init_fleet accepts/masks pasted `c3_api_key`; `c3_compute.py` `_write_container_file` LF helper (`e5aed3e`) | **MED** — on the C3 path; LF fix is harmless on Linux | Port the LF helper; skip the wizard UX (we wire C3 via `.env`) |
| `scripts/list_models.py` (NEW, 181 lines) | **LOW** — dev tooling, no runtime effect, net-new (no conflict) | Port as-is (safe) |
| `58077f3` llm_backends claude-code `--system-prompt-file` + OpenRouter qwen3-coder default | **MED** — reliability for claude-code-agentic | Evaluate against VPS's divergent `llm_backends.py`; port only the system-prompt-file path if VPS lacks it |
| `server/tiers.py` (NEW) frontier/standard **seeding** tiers | **LOW/redundant** — VPS already SOTA-seeds every agent (Task #56) | Skip unless a concrete gap is found |
| dashboard/prompts/server churn | foundation's own evolution; VPS is ahead | Skip |

Net: the genuinely valuable port is the **GPU seeds/kernels** (needed for B anyway)
plus a couple of small safe helpers — *not* a wholesale merge.

## Overarching safety constraints (apply to every workstream)

- **Additive + reversible only.** New challenge_configs rows, new optional config
  fields, new env vars. The 5 live CPU challenges and the 160+ running agents must be
  byte-for-byte unaffected. An agent with no new fields behaves exactly as today.
- **Deploy dance** (per `tig-deploy-sync-check.md` + memories
  `[[master-runs-ahead-of-local]]`, `[[stagnation-pulse-escalation]]`): edit root on
  the VPS → propagate `run_loop.py`/`run_fleet.py` to all 196 worktrees with md5
  verify → staggered restart. For pushes from local, use
  `.claude/hooks/check_master_sync.sh --ack`. Never blind `scp`.
- **Secrets are env-only.** The pasted username `11`, the swarm password, and the C3
  key go into `/root/prometheus-early-beta/.env` (already gitignored) — **never** in
  `fleet.config.json`, code, or any commit. Redact on any echo.
- **Submission gates unchanged** (`tig-submission-gates`, `tig-fee-safety`): GPU
  algorithms still pass benchmark → Lean → red-team → testnet → consensus → EV before
  any mainnet submission. The 50 TIG weekly cap is untouched.
- **No hardcoded protocol/tunable values** (`no-hardcoded-*`): C3 provider, hardware,
  spend cap, failover thresholds, GPU challenge timeouts all go in
  `config/runtime.json`, read via `runtime_config.get`.

---

## Workstream A — Selectively port the GPU seeds + small helpers (no merge)

1. Bring the foundation's GPU seed files into the working tree (read each from
   `origin/main`, write into `initial_algorithms/<gpu>/`): `hypergraph` (construction
   .rs+.cu), `neuralnet_optimizer` (sgd .rs+.cu), `vector_search` (brute_force
   .rs+.cu). These supply `initial_algorithm_files` + `initial_kernel_code` for B.
2. Port `scripts/list_models.py` verbatim (net-new, safe).
3. Port `c3_compute.py` `_write_container_file` LF helper (small, route container
   writes through it) — verify it doesn't conflict with the VPS's 536-line version
   first; re-apply by `Edit`, not patch.
4. `llm_backends.py`: diff VPS vs `origin` for the claude-code `--system-prompt-file`
   path; port **only** if the VPS version lacks it. Treat the VPS's 36-commit version
   as the base; re-grep every call site after editing.
5. Skip `tiers.py`, dashboard, prompts churn unless a concrete gap surfaces.

**Critical files:** `initial_algorithms/<gpu>/seeds/*`, `scripts/list_models.py`,
`scripts/c3_compute.py`, `scripts/llm_backends.py`.

## Workstream B — Enable all 3 GPU challenges in our swarm via C3 (FULL)

1. **Install the `c3` CLI on the VPS** (run_loop hard-exits if `shutil.which("c3")`
   is None — L1467). Per the foundation's AGENTS.md / docs.cthree.cloud. Verify
   `c3 --version` and a `c3 login`/key check.
2. **Wire the C3 key with two env slots** in `.env` (satisfies the "two envs" ask):
   - `C3_API_KEY_FOUNDATION=<their key>` and `C3_API_KEY_OWN=` (empty placeholder for
     a future self-obtained key).
   - `C3_API_KEY=${C3_API_KEY_FOUNDATION}` — the **active selector** run_loop already
     reads (L1228). If the foundation revokes, flip this one line to
     `${C3_API_KEY_OWN}`; no code change.
3. **Seed `challenge_configs` rows** for the 3 GPU challenges via the existing
   `scripts/seed_challenge_config.py` pattern (the same one that fixed
   `[[challenge-tracks-silent-failure]]`): non-empty `tracks` (CRITICAL — empty tracks
   silently zero a challenge), `timeout`, `scoring_direction`, `strategy_tags`,
   `initial_algorithm_files` (from A's seeds), `initial_kernel_code` (the `.cu`).
   Source the track definitions from `tig-challenges/src/<gpu>/` (mainnet truth per
   `tig-challenge-drift.md`).
4. **Allocate agents** to the 3 GPU challenges with `compute=c3`, `hardware=<gpu>`
   (from runtime config, not hardcoded), via `fleet.config.json` + the allocator
   `scripts/tig_allocate_fleet.py`. FULL staffing per the user; the agentic-floor
   guard (`[[stagnation-pulse-escalation]]`) keeps each GPU challenge covered.
5. **C3 spend guardrail** (safety, since key is metered + revocable): a configurable
   daily C3 budget in `config/runtime.json` (`c3.daily_budget_*`, `c3.hardware`,
   `c3.provider`, `c3.kill_switch`) with a monitor that alerts and idles GPU agents
   (reusing the usage-limit idle path `[[usage-limit-idle-rejoin]]`) when the cap is
   hit — defaulted high enough not to throttle "full", but bounded so a runaway or a
   compromised key can't drain it. Status report surfaces C3 spend.

**Critical files:** `scripts/seed_challenge_config.py`, `scripts/tig_allocate_fleet.py`,
`config/runtime.json`, `fleet.config.json`, `.env`, `scripts/run_loop.py` (guardrail
hook only).

## Workstream C — 2-3 flat-rate CLI agents on the foundation swarm, with auto-failover

1. **Per-agent server override.** Pick 2-3 subscription agentic-CLI agents
   (codex / claude-code / gemini — flat-rate, zero marginal LLM cost
   `[[agentic-clis-are-flat-rate]]`). Give those entries in `fleet.config.json`:
   `server_url`/`username`/`swarm_password` referencing **env vars**
   (`FOUNDATION_SWARM_URL`, `FOUNDATION_SWARM_USER`, `FOUNDATION_SWARM_PW`), plus
   `fallback_server_url`/`fallback_username`/`fallback_swarm_password` = **our own
   swarm** (local, same box → always reachable).
2. **`run_fleet.py` change:** honor a per-agent `server_url`/`username`/
   `swarm_password` (+ `fallback_*`) override when present, else fall back to the
   fleet-level triple (today it's L296-301 top-level-only). Additive — agents without
   overrides are unchanged.
3. **Automatic failover in `run_loop.py`** (the core of the new requirement). Make the
   server-interaction layer health-aware, mirroring the existing resilience patterns
   (`_clawrouter_fallback_chain`, the usage-limit idle/rejoin loop):
   - **Active server resolution** tries the primary (foundation); on a connection
     error / timeout / repeated HTTP failure at preflight **or** mid-loop (sync /
     publish), it transparently switches to the `fallback_*` own-swarm and the agent
     **keeps producing** — no exit, no idle, no lost work.
   - **Re-probe** the foundation on a widening backoff (same backoff style as
     `_preflight_idle_bounds`); when it answers healthy again, switch back. Thresholds
     (`failover.fail_threshold`, `failover.reprobe_*`) live in `config/runtime.json`.
   - Net: foundation up → contributes there; foundation down → automatically on our
     swarm; foundation back → rejoins. Fully automatic, "nothing breaks."
4. **Credentials staged in `.env` only** (never in config/code/commits), redacted on
   echo.

**Critical files:** `fleet.config.json`, `scripts/run_fleet.py`, `scripts/run_loop.py`
(server-resolution + sync/publish wrap), `config/runtime.json`, `.env`.

## Workstream D — Bring-back: seed our GPU baselines from the foundation's best

1. Detect on connect **which GPU challenge** the foundation runs (query their
   `/api/state` / leaderboard).
2. Extend the Task #56 `setup.py refresh-baselines` / `scripts/download_algorithm.py`
   machinery to optionally pull the **top-adopted GPU algorithm** from the foundation's
   leaderboard and seed it as our matching GPU challenge baseline
   (`initial_algorithm_files` + kernel), **behind the existing verification gate**
   (stage → `scripts/benchmark.py` feasible → only then swap; keep current baseline on
   fail). The other two GPU challenges seed from the vendored foundation seeds (A).
3. Cadence rides the existing host-only sync gate (`baseline_refresh_hours` in
   runtime config) — no new scheduler, no API hammering.

**Critical files:** `setup.py` (`refresh-baselines`), `scripts/download_algorithm.py`,
`config/runtime.json`.

## Workstream E — Credentials + two-C3-env wiring (secrets hygiene)

Single `.env` edit on the VPS adding (values pasted at execution, never echoed/committed):
`FOUNDATION_SWARM_URL`, `FOUNDATION_SWARM_USER`, `FOUNDATION_SWARM_PW`,
`C3_API_KEY_FOUNDATION`, `C3_API_KEY_OWN` (blank), `C3_API_KEY` (= foundation active).
`.env` is gitignored and loaded by every agent unit (`EnvironmentFile=`). Swap to our
own C3 key later = flip `C3_API_KEY`’s reference, one line.

---

## Rollout order (each gate green before the next; nothing destructive)

1. **E** — stage secrets in `.env` (no behavior change yet).
2. **A** — bring in GPU seeds + safe helpers (files only; no live effect).
3. **B.1-B.2** — install `c3` CLI, verify key works with a single throwaway
   `c3` GPU benchmark (no challenge enabled, no agents moved).
4. **B.3** — seed the 3 GPU `challenge_configs` rows (additive; CPU challenges
   untouched). Verify tracks non-empty and a fresh worktree materializes the GPU
   files + kernel.
5. **C** — `run_fleet.py` per-agent override + `run_loop.py` failover; propagate to
   196 worktrees (md5 verify) → restart **only** the 2-3 detached agents first; watch
   them connect to the foundation and fail over to own swarm when the foundation URL
   is unreachable (test by pointing at a bad URL).
6. **B.4-B.5** — allocate FULL GPU staffing + enable the spend guardrail; staggered
   restart.
7. **D** — wire the bring-back seed on the host sync cadence.

## Verification (end-to-end, evidence-based per `verification-before-completion`)

- **Secrets:** `grep -RInE 'c3_key_|378505e5|"11"' fleet.config.json scripts/ server/`
  returns nothing; keys live only in `.env`.
- **C3 reachable:** one manual `run_loop.py --compute c3 --hardware <gpu>` dry GPU
  benchmark returns a score with no `c3 CLI not found` / `401`.
- **GPU live:** DB query shows 8 `challenge_configs` rows with non-empty `tracks`; a
  fresh agent worktree on a GPU challenge materializes `src/<gpu>/algorithm/` files +
  kernel and benchmarks `feasible:True` via C3.
- **CPU untouched:** the 5 CPU challenges' configs and per-challenge throughput are
  unchanged before/after (status-update skill snapshot diff).
- **Foundation join:** the 2-3 detached agents appear on the foundation dashboard;
  our dashboard shows them only when failed-over.
- **Failover:** with the foundation URL temporarily pointed at an unreachable host,
  the detached agents switch to our swarm within the configured threshold and keep
  producing (log shows the switch); on restore they rejoin — verified live, no manual
  step.
- **Bring-back:** `refresh-baselines` (dry-run first) selects the foundation's top GPU
  algorithm, benchmarks it feasible, and seeds our matching GPU baseline; re-run is
  idempotent (marker skip).
- **C3 spend guardrail:** forcing the daily cap low idles GPU agents (usage-limit idle
  path) and auto-resumes next window — without touching CPU agents.

## Risks / notes

- **C3 metered cost on a revocable key** — the user chose FULL; the spend guardrail +
  the `C3_API_KEY_OWN` slot bound the blast radius if the foundation cuts us off.
- **Vendored-type drift** on GPU challenge compile — handled by the same verification
  gate as Task #56 (feasible-before-swap; keep current baseline on fail).
- **GPU benchmark realism** — C3 runs the official GPU Docker image
  (`nvidia/cuda:12.6.3-...`); the submission gate still re-benches in the official
  image before mainnet.
- **Reconciliation hazard** — A/llm_backends edits land on the VPS's divergent base;
  re-grep every call site after each `Edit` (a blind patch silently skips moved hunks
  per `tig-deploy-sync-check.md`).
