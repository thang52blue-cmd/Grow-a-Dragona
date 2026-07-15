# Progress

> Always load. What works / what's left / known bugs. Only list something under "works" if a green
> `ci/run-tests.sh fast` proves it — this file must not get ahead of the tests.

## What works

Verified as of 2026-07-14 (toolchain installed via Rokit; all three gates run for real, not
smoke-tested):

- `ci/compile-check.sh` → real `COMPILE_OK` (`rojo build` + `luau-lsp analyze`, with real Roblox
  type definitions wired in — see `memory-bank/techContext.md`).
- `ci/run-tests.sh fast` → real `PASSED`, 4 specs, all pure Luau under `src/shared/Domain/`:
  - `Currency.luau` — safe `add`/`spend`: rejects negative/non-integer/NaN amounts, clamps `add` at
    a configured max, rejects `spend` beyond the current balance.
  - `Inventory.luau` — safe `add`/`remove`/`get`: rejects non-positive/non-integer quantities and
    empty item ids, clamps `add` at a configured max stack, deletes the key when a stack reaches 0,
    never mutates its input table.
  - `ProfileSchema.luau` — `default()`/`validate()`: builds a valid empty profile from a starting-
    gold value, accepts a well-formed raw profile, rejects non-table/negative-gold/malformed-
    inventory/missing-meta, defaults a missing session safely.
  - `SessionLock.luau` — `canClaim()`: same-server reclaim always succeeds, a different server is
    blocked while the lock is fresh, and can claim once the lock times out (boundary-tested).
- `ci/lint.sh` → real `PASSED` (selene + stylua, both clean after adding `selene.toml` — see Known
  gaps — and running `stylua src` once).
- `rojo serve default.project.json` starts and listens; the client test harness (`src/client/`)
  connects via `ReplicatedStorage.Remotes` and renders Gold + inventory as plain text with 4
  `TextButton`s (+10 Gold / -10 Gold / +1 Fish / -1 Fish). **Click-tested for real in Studio Play
  mode, 2026-07-14 and 2026-07-15** (Studio MCP access): `Remotes` folder and `PlayerGui.TestHarness`
  render correctly; firing `AddTestGold`/`AddTestFood` round-trips through the services. **Golden
  path now proven (2026-07-15):** with the user's place having `Studio Access to API Services`
  enabled, Gold/Fish actually change and **persist across Stop → Start** — verified 3x, including
  firing a button and stopping immediately with no delay (see `DataService`/`init.server.luau` entry
  below for the bug this surfaced and fixed). The error path (DataStore unavailable) still renders
  `lastError` as on-screen text without crashing, for places without that setting enabled.
- `ci/gate-freshness.sh --stamp` recorded a real green signature after the above.

### Engine-glue layer (built, not unit-tested — by design, see AGENTS.md's deferred engine lane)

- `src/server/Persistence/DataService.luau` — `Load`/`Get`/`Save`/`Release`, in-memory profile
  cache keyed by `userId`, session lock enforced via the tested `SessionLock.canClaim`, DataStore
  calls wrapped in `pcall`. **Fixed 2026-07-14:** the initial `DataStoreService:GetDataStore(...)`
  call is now also `pcall`-wrapped — it used to throw unguarded and crash the entire server
  `require()` chain whenever DataStore was unavailable (e.g. unpublished Studio place), which silently
  prevented `RemotesSetup.Init()` from ever running. `Load`/`Save` now return
  `false, nil, "datastore unavailable: <reason>"` instead. **Known limitation (unchanged):** uses
  `SetAsync` (last-write-wins), not a compare-and-swap `UpdateAsync` — not hardened against true
  cross-server race conditions. That hardening is explicitly backlog item 9's job, not today's.
- `src/server/Services/CurrencyService.luau`, `InventoryService.luau` — thin wrappers binding the
  tested Domain functions to a player's live cached profile.
- `src/server/Remotes/RemotesSetup.luau` + `src/server/init.server.luau` — creates
  `ReplicatedStorage.Remotes` (5 `RemoteEvent`s), wires `Players.PlayerAdded`/`PlayerRemoving` to
  `DataService.Load`/`Release`, and wires each test button's remote to the matching Service call,
  pushing a `{gold, inventory, lastError}` snapshot back to that player after every action.
  **Fixed 2026-07-15:** found via live Studio testing that a button click followed by an immediate
  Stop could lose the change — `Release`'s `Save` call is a yielding `SetAsync`, and nothing held
  server shutdown open for it, while `Release`'s `(ok, err)` return was discarded (a failed save on
  disconnect was completely silent, no console output anywhere). Added `game:BindToClose(...)` to
  release/save every connected player before shutdown completes, and `warn(...)` on save failure on
  both the `PlayerRemoving` and `BindToClose` paths. Reverified 3x live: fire button → stop
  immediately → restart → value persisted correctly every time, no `warn()` output.
- `src/shared/Data/*.json` — `EggConfig`, `DragonConfig`, `FoodConfig`, `EconomyConfig`. See
  `src/shared/Data/README.md` for exactly which numbers are GDD facts vs. engineering placeholders.

## What's left

Backlog item 1 is done. Item 2 (Buy Egg transaction) is partially unblocked — see
`memory-bank/backlog.md`. Items 3-9 haven't started. The test-harness vertical slice's manual Studio
click-test is now done for both the error path and the golden/success path (2026-07-15) — no known
outstanding gaps in the harness itself.

## Known bugs

None found in the tested Domain layer. Fixed this week (not still open):
- 2026-07-14: a JS-style `${}` interpolation typo in the test helper, and `selene` crashing on Luau
  syntax without a `selene.toml` (tooling, not app bugs) — covered under Known gaps / techContext.md.
- 2026-07-14: `DataService`'s unguarded `GetDataStore` call crashed the whole server `require()`
  chain when DataStore was unavailable — fixed with `pcall`.
- 2026-07-15: a save on player-leave/shutdown could silently fail to persist (no `BindToClose`, no
  error logging) — fixed with `game:BindToClose` + `warn()` (see engine-glue layer entry above).

## Known gaps in the scaffold itself

- `luau-lsp analyze` (via `ci/compile-check.sh`) now has real Roblox definitions wired in and
  catches ordinary type errors, but a verified-by-experiment limitation remains: it does not flag a
  nonexistent/mistyped method call on an `Instance`-derived value (e.g. a typo'd `DataStore` method).
  Don't treat a green compile-check as proof against that class of bug in `src/server/`/`src/client/`
  — see `memory-bank/techContext.md`.
- `DataService` save path is last-write-wins (`SetAsync`), not race-hardened — tracked as part of
  backlog item 9, not a bug in today's scope.
- `luau-lsp analyze`/`rojo build` cannot catch runtime-only DataStore-availability errors (proven
  2026-07-14: the unguarded `GetDataStore` crash passed compile-check clean but crashed the whole
  server script at runtime). Don't treat a green compile-check as proof against that class of bug
  either — same caveat as the `Instance`-method-typo gap above, different root cause.
