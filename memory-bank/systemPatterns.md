# System Patterns

> On-demand load. Architecture, patterns, and API contracts. Update this file as transactions are
> implemented — it should describe the repo as it actually is, not the aspiration.

## Layering (README.md architecture table)

| Path | Responsibility |
|---|---|
| `src/shared/Domain/` | pure growth, hatch, reward, production, and validation logic |
| `src/shared/Data/` | prices, timings, odds, food values, production rates, bonuses |
| `src/shared/Types/` | shared typed records and identifiers |
| `src/server/Transactions/` | server-authoritative economy and progression transactions |
| `src/server/Persistence/` | profile loading, session lock, save adapter, migrations |
| `src/server/Services/` | **added 2026-07-14, not in the original README table** — thin server singletons (`CurrencyService`, `InventoryService`) that bind tested `src/shared/Domain/` functions to a player's live cached profile. Lower-level than `Transactions/`: a future `BuyEggTransaction` will likely call `CurrencyService.SpendGold` + `InventoryService.AddItem` as its Atomic Write Set, rather than duplicating that math itself. |
| `src/server/Remotes/` | request parsing, rate limiting, sanitized responses |
| `src/client/` | UI, input, animation, effects, and local presentation |

`src/shared/` must never touch engine globals or do IO (AGENTS.md hard rule; no ADR written for this
yet) so it can be proven by the fast Lune lane without Roblox Studio.

## Rojo tree (`default.project.json`)

```text
ReplicatedStorage.Shared        ← src/shared
ServerScriptService.Server      ← src/server
StarterPlayer.StarterPlayerScripts.Client ← src/client
```

## Transaction model (README.md, AGENTS.md)

Every valuable action is a single server-side flow:

```text
Validate request
→ verify session lock
→ read current snapshot
→ check ownership, balance, state, cooldown, and idempotency
→ build one Atomic Write Set
→ commit once
→ emit post-commit events
→ return sanitized result
```

Clients never choose rewards, rarity, finish time, prices, sell values, or ownership.

## Transaction framework (implemented 2026-07-15, backlog item 2)

Every transaction handler is registered with `TransactionService.RegisterHandler(typeId, handler)`
(ids in `src/shared/Domain/TransactionType.luau`) and implements three functions, called in order
by `TransactionService.Submit(player, requestId, typeId, payload)`:

```lua
handler.Validate(context, payload): (boolean, code: number?)  -- read-only, no profile mutation
handler.Stage(context, payload): (boolean, code: number?)     -- computes context.Staged, no mutation
handler.Commit(context): ()                                   -- the only step allowed to mutate profile
```

`Submit`'s full flow: check `PlayerRuntimeStore` exists and isn't closing → return a cached
`RequestCache` result on a duplicate `requestId` → check the global (30/5s) and per-type rate
limit (`RateLimiter.tryConsume`, both pure) → run inside `TransactionQueue.Run` (per-player FIFO,
`MAX_QUEUE_SIZE = 20`) → build `context` (`Player`, `Profile`, `Runtime`, `RequestId`, `TypeId`,
`TransactionTime`, `Staged = {}`, `ResultData = {}`) → Validate → Stage → Commit → bump
`runtime.Revision` → cache the `TransactionResult` in `RequestCache` → return it.

**Convention per transaction type going forward:** put the actual Validate/Stage/Commit math in a
pure `src/shared/Domain/<Name>Rules.luau` module (no engine globals, has its own `.spec.luau` —
this is what actually proves atomicity/edge-cases per AGENTS.md's hard rule that pure logic lives
in `src/shared/`) and keep the `src/server/Transactions/<Category>/<Name>Transaction.luau` handler
as a thin adapter that supplies server-only config (`ReplicatedStorage.Shared.Data.*`) and calls
into the Rules module. See `BuyEggTransaction.luau` + `BuyEggRules.luau` as the reference pair.

`Revision` and the duplicate-request cache are **runtime-only** (`PlayerRuntimeStore`, keyed by
`player.UserId`, never persisted) — deliberately not added to `Types.Profile`/`ProfileSchema.luau`
to avoid AGENTS.md's save-schema-change gate; see `memory-bank/handoff.md`'s 2026-07-15 entry.

**Known engine-glue caveat (found live via Studio MCP, fixed):** `TransactionQueue.Run` captures
`coroutine.running()` and expects to `coroutine.yield()` before any queued job tries to resume
that thread. The initial queue-processing kick must go through `task.defer`, not a direct call or
`task.spawn` — `task.spawn` runs immediately/synchronously, which can try to resume the caller's
thread before it has actually yielded, and Roblox errors with "cannot spawn non-suspended coroutine
with arguments". This isn't Lune-testable (task-scheduler timing only shows up against the real
Roblox engine) — exactly why a live Studio pass matters for this layer.

## Expected transaction modules (see `src/server/Transactions/README.md`)

```text
Economy/BuyEggTransaction.luau            -- DONE 2026-07-15 (backlog item 2)
Economy/SellProductionEggTransaction.luau
Hatching/StartHatchTransaction.luau       -- DONE 2026-07-16 (backlog item 4)
Hatching/ClaimHatchTransaction.luau       -- DONE 2026-07-16 (backlog item 4)
Dragon/FeedDragonTransaction.luau
Dragon/SetFavoriteTransaction.luau
Production/AssignProducerTransaction.luau
Production/CollectNestTransaction.luau
Display/AssignDisplayTransaction.luau
Display/RemoveDisplayTransaction.luau
```

## Hatch flow (implemented 2026-07-16, backlog item 4)

`StartHatch`/`ClaimHatch` follow the same thin-adapter convention as `BuyEgg`
(`src/server/Transactions/Hatching/*Transaction.luau` → pure
`src/shared/Domain/{StartHatch,ClaimHatch}Rules.luau`). See
`adr/ADR-002-hatch-state-and-dragon-schema.md` for the full decision record; summary:

- `profile.pendingHatches: {[string]: PendingHatch}` and `profile.dragons: {[string]:
  DragonRecord}` are both keyed by ids minted from `profile.meta.nextEntityId` (a shared
  counter) — never by the client-supplied `requestId`, which isn't safe as a persisted
  key across sessions.
- Multiple hatches run concurrently per player; each has its own server-computed
  `FinishAt`. `EggConfig.hatchingTiers.*.hatchDurationSeconds` holds the per-tier
  duration (placeholder values, not yet balanced).
- The hatching egg is a real `Workspace.HatchingEggs.<UserId>.<hatchId>` model
  (`src/server/Services/HatchSpawner.luau`), visible to every client, tagged
  `"HatchingEgg"` via `CollectionService` with `FinishAt`/`Rarity` attributes.
  `src/client/Hatch/HatchCountdownController.luau` renders the countdown from those
  attributes on every client that can see it; nothing about the countdown is
  authoritative, it's pure display.
- `src/client/Hatch/AutoClaimController.luau` auto-fires `ClaimHatch` once a pending
  hatch's `FinishAt` passes; `ClaimHatchRules.Stage` re-checks the server's own clock
  regardless, so this is a convenience trigger, not a trust boundary.
- Dragon rarity is rolled via the new pure `src/shared/Domain/WeightedRoll.luau` against
  the *hatched egg's own* `EggConfig.hatchingTiers[rarity].odds` — no new probability
  table. `DragonRecord` has no `Element` yet (no odds exist for it in
  `DragonConfig.json`) — a follow-up before backlog item 5 needs it.
- `src/shared/Domain/Rarities.luau` (`.List` + `.IsValid`) is the shared rarity
  list/validator now used by `BuyEggRules`, `StartHatchRules`, and `ProfileSchema`.

## Data classification (README.md)

- **Persistent**: Gold, owned eggs, dragons, food, hatch state, growth progress, production state,
  uncollected output, display assignments, boosts, pending claims.
- **Runtime**: models, animations, current targets, temporary cooldowns, remote connections, dirty
  flags, caches, session-lock heartbeat state.
- **Derived**: sell values, final hatch odds, production speed, quality bonuses, display synergy,
  slot limits — always recalculated from authoritative inputs + `src/shared/Data/`, never saved.

## Shared vocabulary fixed by the GDD (`Doc/Grow_a_Dragona_GDD.txt`)

- `Types.Element`: `"Fire" | "Water" | "Earth" | "Light" | "Dark"` (see `src/shared/Types/Types.luau`).
- `Types.Rarity`: `"Common" | "Rare" | "Epic" | "Legendary" | "Mythic"`.
- `Types.EggVariant`: `"Normal" | "Mini" | "Heavy" | "Giant" | "Golden"` — production-egg sell-value
  multiplier, distinct from hatching-egg tier/rarity. Do not conflate the two egg concepts; see
  `memory-bank/CONTEXT.md`.

## Session lock (implemented 2026-07-14)

`src/shared/Domain/SessionLock.luau` is the pure decision function:
`canClaim(existingSession: Types.Session, jobId: string, now: number, timeoutSeconds: number): boolean`.
Same-server reclaim always succeeds; a different server is blocked until `now - existingSession.updatedAt >= timeoutSeconds`.
`src/server/Persistence/DataService.luau` calls this on every `Load` before caching a profile, using
`game.JobId` and `os.time()`. The lock is stored at `profile.meta.session` and persisted with the
profile itself. **Not yet hardened** against a true concurrent-write race (see
`memory-bank/progress.md` "Known gaps" — `DataService.Save` uses `SetAsync`, last-write-wins, not a
compare-and-swap `UpdateAsync`); that's backlog item 9's job.

## Test-harness remote contract (`ReplicatedStorage.Remotes`, implemented 2026-07-14)

Created at runtime by `src/server/Remotes/RemotesSetup.luau` (code-first, no `.model.json`). Five
`RemoteEvent`s, all **intent-only** payloads per AGENTS.md's remote-payload rule — the client never
sends an amount, the server decides it:

```text
AddTestGold    (client → server, no payload)  — server adds a fixed test amount via CurrencyService
SpendTestGold  (client → server, no payload)  — server spends a fixed test amount via CurrencyService
AddTestFood    (client → server, no payload)  — server adds a fixed test item/qty via InventoryService
RemoveTestFood (client → server, no payload)  — server removes a fixed test item/qty via InventoryService
ProfileUpdated (server → client, {gold: number, inventory: {[string]: number}, lastError: string?})
```

This is scaffolding for manual Studio testing, not a real gameplay remote contract.

**Added 2026-07-15 (backlog item 2) — the first real transaction contract:**

```text
Transaction (RemoteFunction, client → server: requestId: number, typeId: number, payload: table)
            (server → client: Types.TransactionResult = {Success, Code, Revision?, Data?})
```

A `RemoteFunction`, not an event, since the caller needs the result synchronously (server-side
`TransactionService.Submit` does the enqueue/Validate/Stage/Commit and returns the result directly
from `OnServerInvoke`). `payload` is intent-only per AGENTS.md §3.1 — for `BuyEgg`:
`{Rarity: string, Amount: number}`; the server looks up price/limits from `EggConfig.json` itself,
never trusting a client-sent price. This is the pattern future transaction types should follow,
not another ad-hoc `RemoteEvent` pair like the test-harness ones above.

No other API contracts (remote names/payload shapes) are committed yet.
