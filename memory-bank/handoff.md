# Handoff

> Always load, read first. Last session's state transfer. Overwritten each `end-session`.

## Session: 2026-07-17 — Backlog item 6: Assign Producer / Collect Nest (Rules/Transaction layer)

**Verified state:** All three gates green: `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh
fast` → `PASSED` (17 specs, up from 14 — 3 new pure Domain spec files), `ci/lint.sh` → `PASSED`
(after `stylua` auto-formatted 3 files it flagged). **Live-verified in Studio Play mode via the
Roblox Studio MCP.**

**What happened:**

1. User asked to restart the Rojo server (it wasn't running) and continue work. Restarted `rojo
   serve` in the background, confirmed it's listening on `localhost:34872` (`curl`/`tasklist` both
   confirmed a real `rojo.exe` process and a valid `/api/rojo` response for project `GrowADragona`).
2. Per `activeContext.md`'s "next task", picked backlog item 6 (Assign Producer and Collect Nest
   transactions). This changes the save schema (`DragonRecord.AssignedSlotId`, two new `Profile`
   sections), which `AGENTS.md` and `adr/ADR-003-feed-dragon-schema.md` both explicitly gate on
   human approval + an ADR — stopped and asked before writing any code.
3. Drafted `adr/ADR-004-farm-slot-and-nest-schema.md` from `docs/prd/core-game-loop.md`'s
   Persistent Data Model / Server Services sections (already the approved reference spec), flagged
   the one open design item (starting Farm Slot count — the PRD never specifies a number) as my own
   placeholder proposal (3, all pre-unlocked), and asked the user via `AskUserQuestion`. **Approved
   as proposed.**
4. Implemented, in order:
   - `Types.luau`: `DragonRecord.AssignedSlotId: number?`, new `FarmSlot`/`ProductionEggInventory`/
     `ProductionConfig` types, `Profile.farmSlots`/`productionEggInventory`.
   - `TransactionType.AssignProducer = 31`; `TransactionCode`s `SlotNotFound=43`,
     `SlotOccupied=44`, `DragonNotAdult=45`, `DragonAlreadyAssigned=46`, `NestEmpty=47`.
   - `src/shared/Data/ProductionConfig.json` (180s interval, 12-egg capacity, 3 starting slots) +
     README entry.
   - `ProfileSchema.luau`: `default()` now takes `startingFarmSlots` and pre-populates that many
     empty slots; `validate()` now takes an optional `startingFarmSlots` for backward-compat
     defaulting, and validates/defaults `farmSlots`/`productionEggInventory`/`AssignedSlotId` as
     additive fields (same precedent as every prior additive field). Updated call sites
     (`DataService.luau`) and existing specs (`ProfileSchema.spec.luau`) for the new signature,
     plus added new spec cases for the new fields.
   - `FeedDragonRules.luau`/`ClaimHatchRules.luau`: preserve/default `AssignedSlotId` when writing a
     `DragonRecord` (Feed) or creating one (Claim, defaults `nil`) — required now that the field is
     part of the type.
   - New pure Domain modules (all spec'd): `ProductionRules.luau` (timestamp→completed-cycles
     calc, the PRD's suggested formula verbatim, capacity-capped, no excess-cycle banking),
     `AssignProducerRules.luau`, `CollectNestRules.luau` (calls `ProductionRules.Advance` before
     reading a slot, so a Collect never misses cycles completed since the last write).
   - Thin handlers `src/server/Transactions/Production/AssignProducerTransaction.luau` +
     `CollectNestTransaction.luau` (removed the folder's `.gitkeep`), registered both in
     `init.server.luau` with per-type rate limits (10/2s, matching Feed/Claim).
   - Test-only harnesses in `RemotesSetup.luau`/`init.server.luau`, mirroring `AddTestFood`'s
     pattern exactly: `AddTestDragon` (grants an already-Adult, unassigned dragon — no fast path
     exists to reach Adult otherwise) and `FastForwardProduction` (rewinds a slot's
     `ProductionStartedAt` so completed-cycle math can be exercised without waiting the real 180s).
5. Ran all 3 CI gates; `stylua` flagged 3 files for formatting (not logic), auto-fixed, re-verified
   green.
6. **Live-verified in Studio Play mode via the Roblox Studio MCP** (real client
   `Transaction:InvokeServer` calls from the **Client** datamodel): confirmed new modules synced
   into the **Edit-mode** DataModel first, then started Play. `AddTestDragon` granted dragon `59`
   (Adult, unassigned). `AssignProducer(DragonUID=59, SlotId=1)` succeeded
   (`Data={DragonUID="59",SlotId=1}`). Then, in one batch: assigning a different Adult (`58`) to the
   now-occupied slot 1 → `SlotOccupied` (44); re-assigning `59` to slot 2 → `DragonAlreadyAssigned`
   (46); assigning a Baby dragon (`40`) to slot 3 → `DragonNotAdult` (45); assigning to slot `99` →
   `SlotNotFound` (43); collecting slot 1 with zero elapsed time → `NestEmpty` (47). All 5 codes
   matched exactly. `FastForwardProduction(1, 630)` (3.5 intervals) then `CollectNest(SlotId=1)` →
   `EggsCollected=3` (floor of 3.5, not 3.5 or 4). An immediate second collect → `NestEmpty` again.
   `FastForwardProduction(1, 9000)` (50 intervals, deliberately way past the 12-egg capacity) then
   `CollectNest` → `EggsCollected=12` exactly (not 50) — confirms the "do not bank excess elapsed
   cycles" rule live, not just in the pure spec. A third immediate collect after the capacity-capped
   one → `NestEmpty` again (confirms `ProductionStartedAt` correctly reset to collection time, not
   left stale). `get_console_output` showed no game-code errors/warnings throughout. Stopped Play
   mode afterward.
7. Updated `memory-bank/backlog.md` (item 6 now `~~DONE~~`, DoD-met note), `progress.md`,
   `activeContext.md`, and this `handoff.md`. Not yet committed.

**Deviations / judgment calls (not user-specified, worth restating):**
- Starting Farm Slot count (3, all pre-unlocked, no unlock economy) is an engineering placeholder I
  proposed and the user approved — the PRD never specifies a number. Revisit if the GDD later adds
  a slot-unlock economy.
- `TransactionType.AssignProducer = 31` was placed in the gap between `FeedDragon=30` and
  `CollectNest=40` (grouped with the other single-dragon-lifecycle transaction) rather than
  renumbering the already-reserved `CollectNest=40`/`SellProductionEgg=41` block.
- No "Remove from Farm Slot" transaction was built (PRD mentions `Adult_Unassigned` as a reachable
  state, but item 6's DoD doesn't require it) — `AssignedSlotId` being nilable means this can be
  added later with no further schema change.
- World-presence (spawning the Adult Dragon + Nest models, an Assign trigger, a Collect
  `ProximityPrompt`) was **deliberately not built this session** — same split as backlog item 5's
  Rules/Transaction-then-Phase-B pattern, stated explicitly in `ADR-004`'s Consequences section.
  There is currently no in-game (non-MCP-test-remote) way for a player to trigger Assign/Collect.

**Do next:**
1. Item 6's world-presence pass (if the human wants it next): reuse `DragonSpawner`'s Nursery-lane/
   tag/`ProximityPrompt` pattern, clone from `ReplicatedStorage.NestModels.Default` (already staged
   in Studio per `memory-bank/systemPatterns.md`). No schema change needed.
2. Backlog item 7 (Sell Production Egg transaction) is next per priority order otherwise — builds
   directly on `Profile.productionEggInventory`.
3. Backlog item 3 (engine-lane activation ADR) remains open/unblocked if the human wants to switch
   lanes instead.
4. This session's work is **not yet committed** — commit it (new files: `adr/ADR-004-...`,
   `src/shared/Data/ProductionConfig.json`, `src/shared/Domain/ProductionRules.luau`/`.spec.luau`,
   `AssignProducerRules.luau`/`.spec.luau`, `CollectNestRules.luau`/`.spec.luau`,
   `src/server/Transactions/Production/AssignProducerTransaction.luau`/`CollectNestTransaction.luau`;
   edited: `Types.luau`, `TransactionType.luau`, `TransactionCode.luau`, `ProfileSchema.luau`/
   `.spec.luau`, `FeedDragonRules.luau`, `ClaimHatchRules.luau`, `DataService.luau`,
   `RemotesSetup.luau`, `init.server.luau`, `src/shared/Data/README.md`, and the memory-bank files
   above) before starting item 6's world-presence or item 7.

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions/machine restarts — **verify with `tasklist`/`curl localhost:34872/api/rojo`
before assuming it's up**. Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"`
prefixed before `ci/*.sh` calls in this environment. After editing a data/script file, don't press
Play immediately — confirm new files/values read back correctly in the **Edit** datamodel via
`search_game_tree`/`execute_luau` first, *then* start Play (done this session: confirmed
`ProductionConfig`/`ProductionRules`/`AssignProducerRules`/`CollectNestRules`/both new transaction
modules appeared before Play started). **New this session:** the `Transaction` RemoteFunction
requires a numeric `requestId` (`PayloadValidator.IsPositiveInteger` in
`TransactionService.Submit`) — passing a string requestId (e.g. `"test-assign-1"`) silently returns
generic `InvalidRequest` (code 1) with no indication the requestId itself was the problem; always
use a plain integer when driving `Transaction:InvokeServer` manually via MCP.
