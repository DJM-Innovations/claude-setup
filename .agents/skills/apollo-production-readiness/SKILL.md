---
name: apollo-production-readiness
description: Use when working on Apollo Protocol releases, dependency updates, Docker/runtime changes, Sepolia/canary/prod gates, or QA verification. Enforces Node 24, latest package checks, real-money safety, and the required local/Sepolia validation matrix.
metadata:
  short-description: Apollo release and QA guardrails
---

# Apollo Production Readiness

Use this skill for Apollo Protocol implementation, release preparation, dependency work, or validation.

## Defaults

- Use Node `24.14.0` or newer Node 24 unless the repo changes its `.nvmrc`/`.node-version`.
- Prefer latest stable packages. Before claiming current dependencies are ready, run `pnpm outdated --format table`.
- Keep Docker on Node 24 images and nginx stable/current images used by the repo.
- Never expose or print secret values. Validate presence, shape, derived public addresses, and balances only.
- Public product copy must not mention internal routing vendors or implementation repos. Keep the customer story SaaS-first.
- Treat all payment, wallet, settlement, reward, and routing changes as real-money paths.

## Required Checks Before “Ready”

Run the narrowest relevant subset during iteration, then run the full set before claiming readiness:

```bash
pnpm typecheck
pnpm test
pnpm build
pnpm test:e2e
pnpm peers check
pnpm audit --audit-level moderate
pnpm outdated --format table
git diff --check
docker compose -f infra/docker-compose.yml config
```

For Docker/runtime changes, rebuild and smoke:

```bash
docker build -t apollo-api:local -f apps/api/Dockerfile .
docker build -t apollo-chat-web:local -f apps/chat-web/Dockerfile .
docker build -t apollo-site:local -f apps/site/Dockerfile .
docker build -t apollo-docs:local -f apps/docs/Dockerfile .
```

Smoke deep links for site/chat/docs and `/health` plus a mock `/v1/chat/completions` request for API.

## Live Sepolia Gate

Before saying Sepolia is green:

```bash
pnpm --filter @apollo/api env:validate:sepolia
pnpm --filter @apollo/api smoke:sepolia
```

Confirm funded deployer/keeper ETH, x402 asset balance, BlockRun wallet USDC balance, CDP auth, and real paid completion through the live route.

## Mobile Gate

For iOS dev-build smoke, Metro must be running:

```bash
EXPO_PUBLIC_API_URL=http://localhost:3000 EXPO_NO_TELEMETRY=1 pnpm --filter @apollo/chat-mobile exec expo start --ios --localhost
maestro test .maestro/apollo-mobile-smoke.yaml
```

If Maestro shows “No script URL provided,” that means the dev bundle was not served; start Metro and rerun before judging app correctness.
