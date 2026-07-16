# ADR-004: Farm Slot and Nest schema (AssignedSlotId, FarmSlot, ProductionEggInventory)

## Status

Accepted — 2026-07-17

## Context

Backlog item 6 (Assign Producer and Collect Nest transactions) is next per priority order.
`adr/ADR-003-feed-dragon-schema.md` explicitly deferred this: "`AssignedSlotId` is deliberately NOT
added yet. It belongs to backlog item 6 (Farm Assignment)'s own schema decision." This is gated per
`AGENTS.md` ("Public save-schema and transaction-contract changes require explicit approval and an
ADR") since it adds new persistent fields to `Types.DragonRecord` and two brand-new `Types.Profile`
sections. Design source is the same user-supplied `docs/prd/core-game-loop.md` (Persistent Data
Model / Server Services and Transactions sections) already used for ADR-002/ADR-003. Approved by
the human 2026-07-17 before any transaction code was written.

## Decision

- `Types.DragonRecord` gains one field: `AssignedSlotId: number?` — `nil` when unassigned. Set on a
  successful `AssignProducerTransaction`, cleared back to `nil` if a slot is ever vacated (no
  "remove from farm" transaction exists yet in this ADR's scope — item 6's DoD only covers
  Assign/Collect — but the field is nilable so a future Remove transaction doesn't need its own
  schema change).
- New `Types.FarmSlot`, matching the PRD's `FarmSlot` table verbatim:
  ```lua
  FarmSlot = {
      SlotId: number,
      AssignedDragonUID: string?,
      ProductionStartedAt: number?,
      UncollectedEggCount: number, -- 0..nestCapacity, server-authoritative
      IsProductionPaused: boolean,
  }
  ```
  Stored as `Profile.farmSlots: { [number]: FarmSlot }`, keyed by `SlotId` (a small integer, not a
  GUID — slots are a small, fixed, pre-allocated set per player, unlike dragons/pending hatches
  which grow unboundedly and use `meta.nextEntityId`-derived string keys).
- New `Types.ProductionEggInventory = { Normal, Mini, Heavy, Giant, Golden }` (all `number`),
  mirroring `EggConfig.productionVariants`' variant names exactly. Stored as
  `Profile.productionEggInventory`. Per the PRD, MVP's `CollectNestTransaction` only ever writes
  `Normal` — the other four fields exist now so the shape doesn't need another schema change when
  variant rolling ships later (same precedent as ADR-003's placeholder `elementOdds`). Not reusing
  the generic `Profile.inventory` bucket here (unlike Food in ADR-003): Production Eggs are a
  distinct, small, fixed-cardinality set of exactly 5 known keys forever, not an open-ended
  item-id-keyed bag, so a dedicated typed table is clearer and still trivially validated.
- **Starting Farm Slot count: 3 slots per player, all pre-unlocked, no slot-unlock economy in this
  ADR's scope.** The PRD says "Add unlocked production slots" but never specifies how many or how
  they're unlocked — this is an engineering placeholder (same kind of open-item call ADR/Phase B
  made for the Nursery's exact world layout), not a GDD-sourced number. `Profile.farmSlots` is
  populated with `SlotId = 1..3`, each `AssignedDragonUID = nil`, `ProductionStartedAt = nil`,
  `UncollectedEggCount = 0`, `IsProductionPaused = false`, in `ProfileSchema.default`.
- New config `src/shared/Data/ProductionConfig.json`: `productionIntervalSeconds = 180` and
  `nestCapacity = 12`, both taken directly from the PRD's stated numbers (not placeholders in the
  same sense as `elementOdds`/hatch durations — the PRD states these as concrete prototype values).
  `startingFarmSlots = 3` is the one placeholder value in this file (see above).
- New `TransactionType.AssignProducer = 31` — placed in the gap between `FeedDragon = 30` and
  `CollectNest = 40`, grouping it with the other single-dragon-lifecycle transaction rather than
  the already-reserved Production/economy block (`CollectNest = 40`, `SellProductionEgg = 41`).
- New `TransactionCode`s starting at `43` (next free id after `MissingFood = 42`): `SlotNotFound`,
  `SlotOccupied`, `DragonNotAdult`, `DragonAlreadyAssigned`, `NestEmpty`.
- Backward compatibility: a `Profile` saved before this ADR has no `farmSlots`/
  `productionEggInventory` and a `DragonRecord` has no `AssignedSlotId`. `ProfileSchema.validate`
  treats all of these as additive, same precedent as every prior additive field in this codebase —
  absence defaults to 3 fresh empty slots / all-zero egg inventory / `AssignedSlotId = nil`, a
  present-but-malformed value still rejects the whole profile.
- Production-cycle math (elapsed → completed cycles → eggs created, capacity pause/resume, no
  banking past capacity) is the PRD's own suggested calculation verbatim — implemented as a pure
  `src/shared/Domain/ProductionRules.luau` function shared by both `CollectNestTransaction` (called
  at collect time to bring the slot current before reading it) and any future read-only "peek at
  current Nest state" need, rather than inlined once into `CollectNestRules`.

## Consequences

- Item 6's two transactions (`AssignProducerTransaction`, `CollectNestTransaction`) can now be
  built against a concrete, approved schema.
- World-presence (spawning the Adult Dragon model + Nest model, a Collect `ProximityPrompt`, and a
  Farm-Slot "Assign" trigger) is explicitly **out of scope for this ADR and this pass** — mirrors
  how backlog item 5 split into a Rules/Transaction session followed by a separate Phase B
  world-presence session. That follow-up will reuse `DragonSpawner`'s Nursery-lane/tag/
  `ProximityPrompt` pattern and clone from `ReplicatedStorage.NestModels.Default` (already staged in
  Studio per `memory-bank/systemPatterns.md`).
- No "Remove from Farm Slot" transaction exists yet (the PRD mentions `Adult_Unassigned` as a
  reachable state via "Removing an Adult from the farm changes it back to `Adult_Unassigned`", but
  item 6's DoD does not require it) — `AssignedSlotId` being nilable means adding one later needs no
  further schema change.
- `productionEggInventory`'s `Mini`/`Heavy`/`Giant`/`Golden` fields stay permanently `0` until
  variant-rolling logic ships; `SellProductionEggTransaction` (item 7) is unblocked to read/write
  this table once built.
