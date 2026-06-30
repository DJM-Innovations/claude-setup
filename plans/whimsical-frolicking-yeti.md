# RE-303 — ID Lineage (`GET /api/addresses/{id}/lineage`), derived from PropertyMasterHistory

## Context

Jira **RE-303** ([API] ID Lineage — PropertyLineage Integration, To Do, parent RE-306) asks for: (1) a function that records lineage when key ID fields (MAK, LocationId, OmniMAK) change on edit, and (2) `GET /api/addresses/{id}/lineage`.

The ticket specifies a new `PropertyLineage` table + a write-on-edit path. **Decision (confirmed with user): do NOT build a new table or write path.** `PropertyMasterHistory` (built/used in RE-301) already stores a full row snapshot on every insert/update/delete — including MAK, LocationId, OmniMAK. So in-record ID lineage is already captured and derivable by diffing consecutive history snapshots for an OmniId. This avoids a redundant table, a dual-write, and drift. The scope reduces to **one read endpoint** that computes lineage on the fly.

(The only thing history can't express is cross-record supersession — MAK X retired → MAK Y under a different record. User confirmed lineage only needs in-record ID changes, so history is sufficient.)

Verified: `PropertyLineage` is absent from repo SQL/Go/routes (greenfield) — not needed. Live dev DB schema couldn't be re-confirmed this session (dev SSH timing out), but the approach reads only `PropertyMasterHistory`, which RE-301 verified exists on dev with 489 rows.

## Approach — new endpoint only

Add `GET /api/addresses/{id}/lineage` ({id} = OmniId, matching the existing `GET /api/addresses/{id}` detail route at `main.go:41`, `r.PathValue("id")`). Auth-required via `authMiddleware`.

### New file: `construction-api/lineage.go`
`handleAddressLineage(w, r)`:
- Guard `dbHub == nil` → 503.
- `id := r.PathValue("id")`; validate as int64 OmniId (400 on non-numeric), mirroring `audit.go`'s omniId handling.
- Query (parameterized, `sql.Named`):
  ```sql
  SELECT PropertyHistoryId, MAK, LocationId, OmniMAK, ChangeReason, UpdatedBy, ValidFrom
  FROM dbo.[PropertyMasterHistory] WHERE OmniId = @id
  ORDER BY ValidFrom ASC, PropertyHistoryId ASC
  ```
- Diff adjacent snapshots in Go: for each consecutive pair, for each of the 3 key fields (`MAK`, `LocationId`, `OmniMAK`), if the normalized value changed, emit a lineage event:
  ```
  { field, from, to, eventDate: cur.ValidFrom, eventType: cur.ChangeReason, changedBy: cur.UpdatedBy }
  ```
  (Normalization: treat NULL/empty as equal-empty, compare via fmt.Sprint, same null-vs-empty handling as RE-300's diff.)
- Return chronological (oldest→newest) JSON: `{ "omniId": <id>, "lineage": [ ...events ] }`. Empty `lineage: []` when no key-field changes (200, not 404) — an address with no ID changes legitimately has empty lineage.
- Errors → `jsonError`; log via `log.Printf` like other handlers.
- Full swagger annotations (`@Tags lineage`, `@Security BearerAuth`, `@Param id path int true`, `@Success 200`, `@Router /addresses/{id}/lineage [get]`).

### Wire route — `main.go`
After the detail route (`main.go:41`):
```go
mux.HandleFunc("GET /api/addresses/{id}/lineage", authMiddleware(handleAddressLineage))
```
Go 1.22 ServeMux treats `/{id}/lineage` as distinct from `/{id}` — no conflict.

### Reuse
- `dbHub` (`db.go`), `jsonError` (`auth.go:122`), the omniId parse+400 pattern and `sql.Named` binding (`audit.go`), `scanResultSet` if convenient (or scan the 7 typed columns directly — direct scan is cleaner here since the column set is fixed).

## Swagger regen
External-linker + ad-hoc-codesign workaround:
`GOBIN=/tmp/swagbin go install -ldflags=-linkmode=external github.com/swaggo/swag/cmd/swag@v1.16.6 && codesign -s - -f /tmp/swagbin/swag && /tmp/swagbin/swag init -g main.go -o ./docs` (run with sandbox disabled). Then `go build ./... && go vet ./...`.

## Files
- **new**: `construction-api/lineage.go`
- **edit**: `construction-api/main.go` (one route)
- **regenerated**: `docs/`
- No SQL, no new table, no frontend (unless you later want a Lineage tab — out of scope for RE-303).

## Verification
1. `go build ./... && go vet ./...` clean; swagger shows `/addresses/{id}/lineage`.
2. Against dev `PropertyMasterHistory` (once dev SSH is back, with a fresh MSAL token):
   - Pick an OmniId whose history shows a MAK/LocationId/OmniMAK change (find via sqlcmd: rows where those differ across `ValidFrom` for one OmniId). Confirm the endpoint returns exactly those transitions, with correct from→to, eventDate, changedBy.
   - An OmniId with no key-field change → `lineage: []`, 200.
   - Non-numeric id → 400; no token → 401; `dbHub` down → 503.
   - Cross-check: the from→to values match a manual sqlcmd diff of that OmniId's history.
3. pr-review-guardian on the diff; iterate to clean.
4. **Do not deploy** until the user gives an explicit "yes" (per the standing deploy rule).

## Out of scope
- New `PropertyLineage` table + write-on-edit path (intentionally not built — history already covers it).
- Cross-record supersession lineage (history can't express it; user scoped it out).
- Frontend lineage view.
