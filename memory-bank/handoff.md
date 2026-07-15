# Handoff

> Always load, read first. Last session's state transfer. Overwritten each `end-session`.

## Session: 2026-07-15 — Buy Egg transaction (backlog item 2) implemented, verified live in Studio

**Verified state:** All three gates green: `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh
fast` → `PASSED` (12 specs, up from 4), `ci/lint.sh` → `PASSED`. Live-verified in Studio via MCP
(Play mode): successful purchase, duplicate-RequestId dedupe, invalid-payload rejection,
insufficient-gold rejection, and rate-limit rejection under burst all behaved correctly with no
console errors from game code.

**What happened:**

1. Read the user's `transaction_mvp_plan_for_claude.md` (a full Transaction MVP framework spec:
   TransactionService/Queue/Type/Code, PayloadValidator, RateLimiter, PlayerRuntimeStore,
   BuyEggTransaction). Adapted it to this repo's actual architecture instead of following it
   literally — see "Deviations from the plan" below for what changed and why.
2. Built the pure (Lune-testable, no engine globals — AGENTS.md hard rule) layer under
   `src/shared/Domain/`: `PayloadValidator`, `RateLimiter`, `RequestCache`, `TransactionType`,
   `TransactionCode`, and `BuyEggRules` (the actual Validate/Stage/Commit math for buying a
   hatching egg). Each has a spec; `BuyEggRules.spec.luau` covers the plan's Test 1-4 (success,
   existing-stack, insufficient-gold, malformed-payload) at this pure layer.
3. Built the engine-glue layer under `src/server/`: `Runtime/PlayerRuntimeStore.luau` (per-player
   queue/rate-limit/dedupe-cache state, runtime-only, never persisted), `Transactions/Core/
   TransactionQueue.luau` (per-player serialization) and `TransactionService.luau` (the
   orchestrator: dedupe -> rate limit -> enqueue -> Validate -> Stage -> Commit -> cache result),
   and `Transactions/Economy/BuyEggTransaction.luau` (thin handler delegating to `BuyEggRules`).
4. Wired it in: `RemotesSetup.luau` now also creates a `Transaction` `RemoteFunction`;
   `init.server.luau` registers the `BuyEgg` handler, sets its rate limit (5 req / 2s), creates/
   closes/removes each player's `PlayerRuntimeStore` alongside the existing profile load/release
   lifecycle, and pushes a `ProfileUpdated` snapshot after every transaction.
5. Extended the client test harness (`src/client/init.client.luau`): "Buy 1 Common Egg" / "Buy 1
   Rare Egg" buttons, a "Retry Last Request" button (resends the exact last RequestId to manually
   verify dedupe), and a `TransactionLabel` showing the last `TransactionResult`.
6. Ran `ci/compile-check.sh` — hit and fixed two real `luau-lsp` issues: (a) casting an
   `any`-typed payload field into a `Types.Rarity` string-literal union tripped a luau-lsp
   widening bug (produced a nonsensical `string | string | string | string | string` type); fixed
   by keeping `BuyEggRules.StagedBuyEgg.Rarity` as plain `string` instead of the literal union,
   since `Validate` already confirmed membership. (b) `pcall(handler.Commit, context)` — since
   `Commit` is typed to return 0 values, luau-lsp only allows destructuring the single `ok`
   boolean, not a second error-message value; dropped that second destructured variable.
7. Live-verified in Studio via the Roblox Studio MCP tools (`rojo serve` was already running;
   Rojo had auto-synced all new files — confirmed via `execute_luau` listing
   `ReplicatedStorage.Shared.Domain`'s children before testing). **Found and fixed a real
   concurrency bug this way:** the first live `Transaction:InvokeServer(...)` call crashed the
   server thread with `cannot spawn non-suspended coroutine with arguments` at
   `TransactionQueue.luau`. Root cause: `TransactionQueue.Run` called `processNext(runtime)`
   *before* reaching its own `coroutine.yield()`; since `task.spawn` runs the next thread
   immediately (not deferred), `processNext`'s `task.spawn(function() job() ... end)` executed
   synchronously and tried to `task.spawn(thread, ok, resultOrErr)` to resume the calling thread
   *before that thread had actually yielded yet* — Roblox rejects resuming a still-running
   coroutine. Fixed by kicking off `processNext` via `task.defer` instead of a direct call, so the
   caller's thread reaches `coroutine.yield()` first; `processNext`'s own recursive continuation
   no longer needs (and no longer has) a `task.spawn` wrapper around `job()`, since `job()` itself
   already hands control back to the original caller synchronously via its own `task.spawn(thread,
   ...)`.
8. Re-ran all three CI gates clean after the fix, then re-verified live: a fresh `BuyEgg` request
   (Common, Amount 1) returned `Success=true, Revision=1`, Gold and `HatchEgg_Common` moved by
   exactly `UnitPrice * Amount`; resending the *same* RequestId returned the byte-identical cached
   result without charging Gold again; an invalid `Amount` (`999999`) returned `InvalidAmount`
   (code 20); an unknown rarity string returned `InvalidEggType` (code 10); a burst of requests
   correctly triggered `RateLimited` (code 6), and once that window cleared, an unaffordable
   `Mythic` purchase correctly returned `NotEnoughCurrency` (code 21). No console errors from game
   code across the whole session (one benign error in the output log was from my own ad-hoc debug
   script, not game code). Note: this is the user's live/shared Studio session, so absolute Gold/
   inventory numbers drifted between checks (consistent with the user also having the Play window
   open) — the *deltas* and *codes* per call are what were verified, not absolute totals.

**Deviations from the plan** (implementation-scope adaptations, not architecture decisions — no
new ADR filed; see `adr/ADR-001-initial-toolchain-and-structure.md` for the bar that would trigger
one):
- **No profile save-schema change.** The plan wanted `profile.Metadata.Revision` (persisted) and
  `Statistics.*` counters. AGENTS.md gates "changing live save schemas" behind explicit approval +
  an ADR, and neither is needed for the actual backlog-2 DoD (atomic commit + dedupe). `Revision`
  is implemented as a **runtime-only**, session-scoped counter on `PlayerRuntimeStore` instead —
  observable behavior (increments on success, unchanged on failure) matches the plan's test
  expectations without touching `Types.Profile`/`ProfileSchema.luau`. `Statistics` tracking was
  dropped entirely as out of scope for this backlog item.
- **`EggTypeId` (numeric) -> `Rarity` (string).** The plan's `EggConfig` used a numeric
  `EggTypeId`; this repo's `EggConfig.json` already keys hatching tiers by `Rarity`
  (`Common`/`Rare`/`Epic`/`Legendary`/`Mythic`, GDD-sourced). Reused that instead of introducing a
  parallel numeric-id config.
- **No separate `InventoryRepository`.** The existing `src/shared/Domain/Inventory.luau` (`add`/
  `remove`, already pure/immutable) already satisfies the Stage/Commit split the plan wanted;
  `BuyEggRules.Stage` calls `Inventory.add` directly.
- **`enabled` / `maxPurchaseAmount` added to `EggConfig.json`** per tier — engineering
  placeholders (not GDD-sourced), documented in `src/shared/Data/README.md`.
- **`TransactionCode.RateLimited = 6`** added — the plan's own code list didn't have one, despite
  describing rate limiting as required behavior.

**Do next:** backlog item 2 is DONE. Next up is backlog item 3 (engine-lane activation ADR) or
item 4 (Start Hatch / Claim Hatch transactions) — see `memory-bank/backlog.md`. If item 4 is
picked, `TransactionType.StartHatch`/`ClaimHatch` ids already exist (reserved, unused); the queue/
service/rate-limiter framework built this session is meant to be reused as-is for every future
transaction type — only a new pure `*Rules.luau` + thin handler should be needed per type.

**Environment note (unchanged):** `rojo serve` keeps running across Studio sessions.
Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"` prefixed before `ci/*.sh`
calls in this environment. **New this session:** the Studio MCP's `execute_luau` on the `Server`
datamodel does NOT reliably share Luau's `require()` module cache with the live running game (a
`require`'d module's internal state came back as freshly-empty/nil when introspected this way) —
don't trust ad-hoc server-side state dumps via MCP for anything beyond read-only sanity checks;
prefer asserting behavior through the actual remote/UI surface (which this session did once that
was noticed).
