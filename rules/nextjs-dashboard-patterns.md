# Next.js Dashboard Patterns (Ampersend)

**Source**: PR #397 review by @cmwhited + patterns from PRs #391, #367, #361, #320, #316, #314, #341, #349, #383, #373

These rules are NON-NEGOTIABLE. Every single one must be followed. Violations will result in PR review comments.

---

## 1. Server/Client Component Boundary (CRITICAL)

### NEVER put `"use client"` in page, layout, or loading files

```
FORBIDDEN:
  app/**/page.tsx    → "use client"
  app/**/layout.tsx  → "use client"
  app/**/loading.tsx → "use client"
```

### Page files are async server components that prefetch data

### Use `PageProps` for page component type signatures

```typescript
// CORRECT — uses auto-generated PageProps type (no import needed)
export default async function ExamplePage(props: Readonly<PageProps<"/example">>) {
  const searchParams = await props.searchParams
  // ...
}

// CORRECT — dynamic route
export default async function AgentPage({ params }: PageProps<"/marketplace/[agentId]">) {
  const { agentId } = await params
  // ...
}

// WRONG — inline type
export default async function AgentPage({ params }: { params: Promise<{ agentId: string }> }) {}
```

```typescript
// CORRECT: app/(app-layout)/example/page.tsx
import { api } from "@/services/trpc"
import { ExampleContent } from "@/Components/Example/ExampleContent"

export default async function ExamplePage() {
  void api.router.query.prefetch(args)
  void api.router.otherQuery.prefetch(otherArgs)

  return <ExampleContent />
}
```

```typescript
// WRONG: app/(app-layout)/example/page.tsx
"use client"
import { api } from "@/Providers/TRPCProvider"
// ... hooks, state, everything in the page file
```

### Client components go in `Components/` directory

```
app/(app-layout)/example/page.tsx        → Server component (prefetch + render)
Components/Example/ExampleContent.tsx     → Client component ("use client", hooks, state)
```

### Two different tRPC imports — NEVER mix them

| Context | Import | Methods |
|---------|--------|---------|
| Server (page.tsx) | `import { api } from "@/services/trpc"` | `.prefetch()` |
| Server (API routes) | `import { api } from "@/services/trpc"` | direct calls (e.g., `await api.user.payments()`) |
| Client (Components/) | `import { api } from "@/Providers/TRPCProvider"` | `.useQuery()`, `.useSuspenseQuery()`, `.useMutation()` |

**NEVER** use `createTRPCContext()`/`createCaller()` manually — the `api` from `@/services/trpc` handles context creation and provides a caching layer.

---

## 2. Every Page Route MUST Have `loading.tsx`

```
app/(app-layout)/example/
  page.tsx       ← async server component
  loading.tsx    ← suspense boundary skeleton
```

Loading pages use `animate-pulse` skeleton UI:

```typescript
// loading.tsx
export default function ExampleLoading() {
  return (
    <div className="animate-pulse space-y-6 pb-12">
      <div className="h-6 w-40 rounded bg-elevated" />
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: 6 }, (_, i) => (
          <div key={i} className="h-48 rounded-12 bg-elevated" />
        ))}
      </div>
    </div>
  )
}
```

---

## 3. `useQuery` `select` Over `useMemo`

### ALWAYS use `select` for data transformations from a single query

```typescript
// CORRECT
const { data: agentNames } = api.agents.list.useQuery({}, {
  staleTime: 30_000,
  select: (agents) => {
    const map = new Map<string, string>()
    for (const a of agents) {
      map.set(a.address.toLowerCase(), a.name)
    }
    return map
  },
})

// WRONG
const { data: agents } = api.agents.list.useQuery({})
const agentNames = useMemo(() => {
  const map = new Map<string, string>()
  for (const a of agents ?? []) {
    map.set(a.address.toLowerCase(), a.name)
  }
  return map
}, [agents])
```

### When `useMemo` is acceptable:
- Combining data from MULTIPLE queries
- Transformations that depend on component state (search, filters)
- Deriving data from non-query sources

---

## 4. GDS Components and Icons (MANDATORY)

### Always check GDS before creating custom UI

| Need | GDS Component |
|------|---------------|
| Search input | `<Search />` from `@graphprotocol/gds-react` |
| Status badge | `<Status variant="success|error|default" />` |
| Tab navigation | `<TabSet>` with `<TabSet.Tab>` |
| Segmented control | `<SegmentedControl>` |
| Buttons | `<Button>` (supports `href` for link behavior) |
| Modals | `<Modal>` with `<Modal.Header>`, `<Modal.Body>`, `<Modal.Footer>` |
| Copy to clipboard | `<CopyButton>` |
| Tooltips | `<Tooltip>` |
| Descriptions | `<DescriptionList>` |
| Tags/badges | `<Tag>` |

### Always use GDS icons — NEVER inline SVGs

```typescript
// CORRECT
import { BellIcon, GearSixIcon, GridFourIcon, UsersIcon } from "@graphprotocol/gds-react/icons"
<BellIcon alt="Notifications" className="h-5 w-5" />

// WRONG
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
  <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
</svg>
```

### Common icon mappings:
| Purpose | GDS Icon |
|---------|----------|
| Dashboard/grid | `GridFourIcon` |
| Users/agents | `UsersIcon` |
| Transactions | `ArrowsDownUpIcon` |
| Analytics/chart | `ChartLineUpIcon` |
| Marketplace | `CompassIcon` |
| Documentation | `BookOpenIcon` |
| Teams | `BriefcaseIcon` |
| Notifications | `BellIcon` |
| Settings | `GearSixIcon` |
| Theme (dark) | `MoonIcon` |
| Theme (light) | `SunIcon` |
| API keys | `KeyIcon` |
| Warning/danger | `WarningIcon` |
| Download/export | `DownloadIcon` |

---

## 5. Navigation: Links Over Router

### NEVER use `router.push()` or `router.replace()` for navigation

```typescript
// CORRECT — accessible, screen-reader friendly, opens in new tab
<Link href={`/agents/${agent.address}`}>
  {agent.name}
</Link>

// CORRECT — GDS button as link
<Button href="/agents/create" variant="primary">
  Create Agent
</Button>

// WRONG — not accessible, no right-click "open in new tab"
<button onClick={() => router.push(`/agents/${agent.address}`)}>
  {agent.name}
</button>
```

### When `router.push` IS acceptable:
- After a form submission / mutation success (programmatic redirect)
- In a `useEffect` for auth redirects

---

## 6. tRPC Utils Over queryClient

### Use `api.useUtils()` instead of `useQueryClient()` + `getQueryKey()`

```typescript
// CORRECT
const utils = api.useUtils()

const mutation = api.agents.update.useMutation({
  async onSuccess(data) {
    await utils.agents.list.invalidate()
    await utils.agents.authorizedSellers.setData(address, data)
  },
})

// Read cached data
const cached = utils.agents.authorizedSellers.getData(address)

// WRONG
const queryClient = useQueryClient()
const key = getQueryKey(api.agents.authorizedSellers, address, "query")
queryClient.setQueryData(key, data)
queryClient.getQueryData(key)
```

---

## 7. Mutation State Over Custom State

### Use mutation return values, not custom status state

```typescript
// CORRECT
const { isPending, isSuccess, isError, mutateAsync } = api.foo.bar.useMutation()
// isPending, isSuccess, isError are derived automatically

// WRONG
const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle")
const { mutateAsync } = api.foo.bar.useMutation()
setStatus("loading")
try { await mutateAsync(); setStatus("success") }
catch { setStatus("error") }
```

---

## 8. CSS/Tailwind Over State for UI

### Use Tailwind pseudo-classes instead of state for focus/hover/active

```typescript
// CORRECT — CSS handles visibility
<div className="group relative">
  <Search ... />
  <div className="invisible group-focus-within:visible">
    {/* dropdown */}
  </div>
</div>

// WRONG — state for something CSS can handle
const [focused, setFocused] = useState(false)
<input onFocus={() => setFocused(true)} onBlur={() => setFocused(false)} />
{focused && <div>{/* dropdown */}</div>}
```

---

## 9. Hardcoded Values

### Colors should use CSS custom properties or GDS tokens

```typescript
// CORRECT
const COLORS = [
  "var(--color-brand, #438d94)",
  "var(--color-indigo-500, #6366f1)",
]

// WRONG — won't adapt to theme changes
const COLORS = ["#438d94", "#6366f1"]
```

### Chain data should use `viem/chains`

```typescript
// CORRECT
import { base, mainnet, polygon } from "viem/chains"
const name = mainnet.name  // "Ethereum"
const id = mainnet.id      // 1

// WRONG — hardcoded chain data
const CHAINS = { 1: { name: "Ethereum" }, 8453: { name: "Base" } }
```

---

## 10. Component Architecture

### Keep components small and focused

> "Please, I am begging, don't put _more_ things into this component. If we do anything, it should be to pull components _out_" — @cmwhited PR #341

### Directory structure follows feature hierarchy

```
Components/
  Agent/
    AgentDetails/
      ConfigPane/
        AgentKeysList.tsx
  Dashboard/
    Agents/
      AgentCard.tsx
    Dashboard.tsx
  Discovery/
    AgentDetails.tsx
    AddToSellerModal.tsx
  Marketplace/
    MarketplaceContent.tsx
```

### Component props should use `Readonly<>`

```typescript
// CORRECT (Chris's pattern)
function AgentCard({ address }: Readonly<{ address: Domain.Address }>) {}

// ACCEPTABLE
interface AgentCardProps { address: Domain.Address }
function AgentCard({ address }: AgentCardProps) {}
```

---

## 11. Data Processing Location

### Heavy data manipulation should NOT happen on the client

> "Browser clients are pretty bad and inefficient at doing these kind of large data manipulations. This should likely be moved either to the tRPC/nextjs server, or to the api layer" — @cmwhited

- Simple filtering/mapping → `select` in `useQuery` (client is fine)
- Complex aggregation, merging multiple datasets → tRPC server procedure or API layer
- Sorting large datasets → API/database layer with ORDER BY

---

## 12. Naming Conventions

### Use established project terminology

- "seller" not "vendor" — the project uses "seller" consistently
- Match UI copy to action labels (e.g., button says "Sign in" → loading text says "Signing in")

---

## 13. Query Patterns

### Use `useSuspenseQuery` for critical data, `useQuery` for optional

```typescript
// Critical data — component can't render without it
const [agent] = api.discovery.byId.useSuspenseQuery(agentId)

// Optional/secondary data — component has fallback
const { data: keys, isLoading } = api.agents.keys.useQuery(address)
```

### Use `useQueries` for dynamic parallel fetches

```typescript
// CORRECT — when fetching N items in parallel
const results = api.useQueries(
  agents.map((agent) => ({
    queryKey: ['agents', 'sellers', agent.address],
    queryFn: () => fetchSellers(agent.address),
  }))
)

// WRONG — calling useQuery in a .map()
const sellerQueries = agents.map((agent) => ({
  query: api.agents.sellers.useQuery(agent.address),
}))
```

---

## 14. Existing Patterns to Follow

### URL state for shareable filters

Carry state through URL search params instead of component state when the state should be shareable:

```typescript
// Timerange passed via URL (Chris's PR #367)
<Link href={`/agents/${address}?timerange=${timerange}`}>Details</Link>
```

### Use established libraries

```typescript
// CORRECT — use date-fns for formatting
import { format } from "date-fns/format"
format(new Date(timestamp), "MMM d, yyyy")

// WRONG — manual string slicing
timestamp.slice(0, 10)
```

### Follow existing directory conventions

- Tests go in `test/` directory, NOT `__tests__/`
- Use the existing CLI framework for scripts, don't create standalone files

---

## 15. TypeScript Patterns

### Use `Array<T>` not `T[]` (eslint rule: `@typescript-eslint/array-type`)

```typescript
// CORRECT
const items: Array<string> = []
function process(addresses: Array<Domain.Address>) {}

// WRONG (lint error)
const items: string[] = []
function process(addresses: Domain.Address[]) {}
```

### Sort destructured keys (eslint rule: `sort-destructure-keys`)

```typescript
// CORRECT
const { isError, isPending, isSuccess, mutateAsync } = useMutation()
function Component({ name, onChange, value }: Props) {}

// WRONG
const { mutateAsync, isPending, isSuccess, isError } = useMutation()
function Component({ value, onChange, name }: Props) {}
```

### Use Domain types from `@edgeandnode/x402-domain`

```typescript
// CORRECT
import type { Domain } from "@edgeandnode/x402-domain"
function getAgent(address: Domain.Address): Domain.ID {}

// WRONG
function getAgent(address: string): string {}
```

---

## 16. GDS TabSet — Full Pattern (CRITICAL)

### ALWAYS use `TabSet.Panels` and `TabSet.Panel` for tab content

```typescript
// CORRECT — GDS manages transitions, accessibility, and mounting
<TabSet value={activeTab} onChange={setActiveTab}>
  <TabSet.Tabs>
    <TabSet.Tab value="discover">Discover</TabSet.Tab>
    <TabSet.Tab value="sellers">Authorized Sellers</TabSet.Tab>
  </TabSet.Tabs>
  <TabSet.Panels>
    <TabSet.Panel value="discover"><DiscoverContent /></TabSet.Panel>
    <TabSet.Panel value="sellers"><SellersContent /></TabSet.Panel>
  </TabSet.Panels>
</TabSet>

// WRONG — manual conditional rendering bypasses GDS transitions
<TabSet value={activeTab} onChange={setActiveTab}>
  <TabSet.Tabs>...</TabSet.Tabs>
</TabSet>
{activeTab === "discover" && <DiscoverContent />}
{activeTab === "sellers" && <SellersContent />}
```

### Use GDS TabSet EVERYWHERE tabs appear — even dashboard overview/agents tabs

---

## 17. Search Param Atoms for Tab State

### Tab state should be in URL search params, not component state

```typescript
// CORRECT — URL-shareable, persists across navigation
const [tab, setTab] = useTabAtom() // atom synced with ?tab= search param

// WRONG — tab state lost on navigation
const [tab, setTab] = useState("discover")
```

### Server page prefetch must use ACTUAL search params

```typescript
// CORRECT — prefetch uses the timerange from URL
export default async function AnalyticsPage(props: PageProps) {
  const searchParams = await props.searchParams
  const preset = parseTimerange(searchParams["timerange"]) ?? "30d"
  void api.user.spendEarningsOverlay.prefetch({ preset })
  return <AnalyticsContent />
}

// WRONG — hardcoded prefetch ignores URL state
export default async function AnalyticsPage() {
  void api.user.spendEarningsOverlay.prefetch({ preset: "30d" }) // ← always 30d!
  return <AnalyticsContent />
}
```

---

## 18. Mutations: Batch Over Iterate

### Build final state and call mutation ONCE

```typescript
// CORRECT — build array, one mutation call
const handleSave = async () => {
  const newSellers = buildNewSellersFromPendingChanges(currentSellers, pendingChanges)
  await mutation.mutateAsync({ address, authorized_sellers: newSellers })
}

// WRONG — iterate and mutate per item
const handleSave = async () => {
  for (const [addr, shouldHave] of pendingChanges) {
    const current = getCached(addr)
    await mutation.mutateAsync({ address: addr, authorized_sellers: [...current, seller] })
  }
}
```

---

## 19. GDS Form Components

### Always use GDS form components over raw HTML

| Need | GDS Component | NOT |
|------|---------------|-----|
| Checkbox | `<Checkbox>` from `@graphprotocol/gds-react` | `<input type="checkbox">` |
| Text input | `<Input>` from `@graphprotocol/gds-react` | `<input type="text">` |
| Search | `<Search>` from `@graphprotocol/gds-react` | custom search input |
| Select | `<Select>` from `@graphprotocol/gds-react` | `<select>` |

---

## 20. Heavy Operations in API Routes

### CSV export, PDF generation, etc. belong in Next.js API routes

```typescript
// CORRECT — server-side route uses api from @/services/trpc (cached, no manual context)
// app/api/export/route.ts
import { api } from "@/services/trpc"

export async function GET(request: NextRequest) {
  const data = await api.user.payments()
  const csv = generateCSV(data)
  return new Response(csv, { headers: { "Content-Type": "text/csv" } })
}

// Client just links to the endpoint
<Button href="/api/export?type=transactions" download>Export CSV</Button>

// WRONG — manually creating context and caller
import { createTRPCContext } from "@/server/context"
import { createCaller } from "@/server/root"
const ctx = await createTRPCContext()
const caller = createCaller(() => ctx)
const data = await caller.user.payments() // ← no caching, verbose

// WRONG — client-side Blob creation from large datasets
const handleExport = () => {
  const csvString = buildCSVFromData(allTransactions) // heavy in browser
  const blob = new Blob([csvString], { type: "text/csv" })
  // ...
}
```

---

## 21. Use Existing Utilities

### Check `utils/` before writing helpers

| Need | Use | File |
|------|-----|------|
| Shorten address | `shorten(address)` | `utils/address.ts` |
| Format amount | `formatAmount(bigint)` | `utils/amounts.ts` |

```typescript
// CORRECT
import { shorten } from "@/utils/address"
shorten(address) // "0x1234...5678"

// WRONG — reinventing the wheel
`${address.slice(0, 6)}...${address.slice(-4)}`
```

---

## 22. npm Scripts for CLI Subcommands

### Don't create separate scripts — use subcommand args

```json
// CORRECT — pass subcommand directly
"db:seed": "tsx scripts/seed.ts",
// Usage: pnpm run db:seed agents, pnpm run db:seed dashboard

// WRONG — separate scripts for subcommands
"db:seed": "tsx scripts/seed.ts agents",
"db:seed:dashboard": "tsx scripts/seed.ts dashboard"
```

---

## 23. Component State Ownership

### State should live in the component that uses it

```typescript
// CORRECT — search state in the component that renders the search
function SellersList() {
  const [search, setSearch] = useState("")
  return <Search value={search} onChange={setSearch} />
}

// WRONG — lifting state to parent that doesn't use it
function MySellersTab() {
  const [search, setSearch] = useState("")
  return <SellersList search={search} onSearchChange={setSearch} />
}
```

---

## 24. GDS Button with addonBefore for Icon Buttons

### Use `addonBefore` for icon+text buttons, not inline text symbols

```typescript
// CORRECT
import { PlusIcon } from "@graphprotocol/gds-react/icons"
<Button variant="secondary" size="small" addonBefore={<PlusIcon alt="" />}>
  Add to Sellers
</Button>

// WRONG — text symbol instead of icon
<Button variant="secondary" size="small">
  + Add to Sellers
</Button>
```

---

## Quick Reference Checklist

Before submitting a PR, verify:

- [ ] No `"use client"` in any `page.tsx`, `layout.tsx`, or `loading.tsx`
- [ ] Every page route has a `loading.tsx`
- [ ] Pages import from `@/services/trpc` and use `.prefetch()`
- [ ] Page components use `PageProps<"/route">` type, not inline param types
- [ ] API routes use `api` from `@/services/trpc`, NOT manual `createTRPCContext`/`createCaller`
- [ ] Server prefetch uses ACTUAL search params from URL, not hardcoded defaults
- [ ] Client components import from `@/Providers/TRPCProvider`
- [ ] No `useMemo` wrapping single-query transformations (use `select`)
- [ ] No inline SVGs — all icons from `@graphprotocol/gds-react/icons`
- [ ] No `router.push`/`router.replace` for navigation — use `<Link href>`
- [ ] No `useQueryClient()` + `getQueryKey()` — use `api.useUtils()`
- [ ] No custom state for mutation status — use `isPending`/`isSuccess`/`isError`
- [ ] No hardcoded colors — use CSS custom properties
- [ ] Chain data uses `viem/chains`
- [ ] Destructured keys are sorted alphabetically
- [ ] Array types use `Array<T>` not `T[]`
- [ ] GDS components used EVERYWHERE available (Search, Status, TabSet, Button, Modal, Checkbox, etc.)
- [ ] TabSet uses `TabSet.Panels`/`TabSet.Panel` — no conditional rendering
- [ ] Tab state in search param atoms, not `useState`
- [ ] Mutations called ONCE with final state, not per-item in a loop
- [ ] Heavy operations (CSV, PDF) in Next.js API routes, not client-side
- [ ] Use existing utils (`shorten`, `formatAmount`) — don't reinvent
- [ ] Raw HTML inputs replaced with GDS form components (Checkbox, Input, etc.)
- [ ] Button icons use `addonBefore={<Icon />}`, not text symbols like `+`
- [ ] npm scripts don't create separate entries for subcommands
