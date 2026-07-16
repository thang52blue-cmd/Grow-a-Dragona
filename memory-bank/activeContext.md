# Active Context

> Always load. Current focus, last 3 done, current + next task. Overwrite this each `end-session`.

## Current focus

Backlog items 1, 2, 4, 5 (world-presence included), and 6 (Rules/Transaction layer) are complete.
A player can now be assigned an Adult dragon to a Farm Slot and Collect its Nest's Production Eggs
via the real `Transaction` remote — schema approved in
`adr/ADR-004-farm-slot-and-nest-schema.md`. **World-presence for item 6 (Adult Dragon + Nest world
models, Assign/Collect `ProximityPrompt`s) is explicitly not built yet** — same split as item 5's
Rules/Transaction-then-Phase-B pattern; there is currently no in-game (non-MCP) way to trigger
Assign/Collect.

**Everything for this backlog item was driven by the user-supplied plan doc, saved verbatim at
`docs/prd/core-game-loop.md`** — read that first before starting item 6's world-presence pass or
item 7 (Sell Production Egg), which build directly on `Profile.farmSlots`/`productionEggInventory`.

## Last 3 done (2026-07-17 session)

1. Restarted `rojo serve` (was not running) and confirmed it's listening on `localhost:34872`.
2. Wrote and got explicit human approval for `adr/ADR-004-farm-slot-and-nest-schema.md`:
   `DragonRecord.AssignedSlotId`, `Profile.farmSlots`/`productionEggInventory`, new
   `ProductionConfig.json` (180s interval, 12-egg capacity, 3 starting slots — the slot count is an
   engineering placeholder, not GDD-sourced), `TransactionType.AssignProducer = 31`, new
   `TransactionCode`s from 43.
3. Implemented backlog item 6's Rules/Transaction layer: `ProductionRules.luau` (pure
   timestamp→completed-cycles calc), `AssignProducerRules.luau`, `CollectNestRules.luau` (all
   spec'd, 17 specs total now), thin `AssignProducerTransaction.luau`/`CollectNestTransaction.luau`
   handlers, `ProfileSchema` backward-compat for the new additive fields. All 3 CI gates green.
   Live-verified in Studio Play mode via the Roblox Studio MCP: real `Transaction:InvokeServer`
   calls for both transactions, all 5 rejection codes confirmed, and a new `FastForwardProduction`
   test-only remote proved the floor-division cycle math and 12-egg capacity cap (no excess-cycle
   banking) against the real server clock path. No console errors.

## Current task

Memory write-back for this session (this update). This session's work is **not yet committed**.

## Next task

1. Item 6's world-presence pass: reuse `DragonSpawner`'s Nursery-lane/tag/`ProximityPrompt`
   pattern to spawn the Adult Dragon + its Nest once assigned to a slot (clone from
   `ReplicatedStorage.NestModels.Default`, already staged in Studio), plus an Assign trigger and a
   Collect `ProximityPrompt`. No schema change needed — `ADR-004` already covers it.
2. Item 7 (Sell Production Egg transaction) is next per priority order once item 6's world-presence
   is decided/deferred by the human.
3. Item 3 (engine-lane activation ADR) remains open/unblocked if the human wants to switch lanes.
4. Commit this session's work (new: `adr/ADR-004-...`, `ProductionConfig.json`,
   `ProductionRules.luau`/`.spec`, `AssignProducerRules.luau`/`.spec`,
   `CollectNestRules.luau`/`.spec`, `Production/AssignProducerTransaction.luau`,
   `Production/CollectNestTransaction.luau`; edited: `Types.luau`, `TransactionType.luau`,
   `TransactionCode.luau`, `ProfileSchema.luau`/`.spec`, `FeedDragonRules.luau`,
   `ClaimHatchRules.luau`, `DataService.luau`, `RemotesSetup.luau`, `init.server.luau`, and the
   memory-bank files above) before starting further work.

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions — verify with `tasklist`/`curl localhost:34872/api/rojo` before assuming
it's up. Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"` prefixed before
`ci/*.sh` calls. Confirm new files sync into the **Edit-mode** DataModel (via `search_game_tree`)
before starting Play — this session confirmed `ProductionConfig`/`ProductionRules`/
`AssignProducerRules`/`CollectNestRules`/the two new transaction modules all appeared under their
expected paths before Play started. The `Transaction` remote requires a numeric `requestId`
(`PayloadValidator.IsPositiveInteger`) — a string requestId silently fails with generic
`InvalidRequest` (code 1), which cost a debugging round-trip this session.
