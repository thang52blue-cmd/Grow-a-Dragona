# Decision Log

> On-demand load. Append-only index. Full ADRs live under `adr/`, one file each. Never rewrite a
> past entry — supersede it with a new dated one.

- 2026-07-14 — **ADR-001: Initial toolchain and project structure.** Pinned rojo 7.7.0, lune 0.10.5,
  selene 0.31.0, stylua 2.5.2, luau-lsp 1.68.1 in `rokit.toml`; established the `src/shared` /
  `src/server` / `src/client` Rojo tree. See `adr/ADR-001-initial-toolchain-and-structure.md`.
- 2026-07-16 — **ADR-002: Hatch state and dragon-inventory schema.** Added `Profile.pendingHatches`/
  `dragons` (keyed by a shared `meta.nextEntityId` counter, not client requestId); multiple
  concurrent hatches allowed; client-triggered/server-revalidated claim; hatching-egg world model is
  Runtime-only, respawned on rejoin. See `adr/ADR-002-hatch-state-and-dragon-schema.md`.
- 2026-07-16 — **ADR-003: Feed Dragon schema (Element, GrowthStage, FeedCount).** Added
  `DragonRecord.Element`/`GrowthStage`/`FeedCount`; Element rolled at hatch via generalized
  `WeightedRoll.pick` + new `Elements.luau` + placeholder equal-weight `DragonConfig.elementOdds`;
  Food reuses the existing generic `Profile.inventory` (no new `FoodInventory` bucket); Farm Slot/
  Nest schema deferred to its own ADR. See `adr/ADR-003-feed-dragon-schema.md`.
- 2026-07-17 — **ADR-004: Farm Slot and Nest schema (AssignedSlotId, FarmSlot,
  ProductionEggInventory).** Added `DragonRecord.AssignedSlotId`; new `Profile.farmSlots`
  (3 pre-unlocked slots, placeholder count) and `Profile.productionEggInventory` (5 fixed variant
  keys, MVP only writes `Normal`); new `ProductionConfig.json` (180s interval, 12-egg capacity);
  `TransactionType.AssignProducer = 31`; new `TransactionCode`s from 43. World-presence deferred to
  a later pass, same as item 5's Phase B split. See `adr/ADR-004-farm-slot-and-nest-schema.md`.
- 2026-07-17 — **ADR-005: Farm Plot world-presence, auto Farm-Slot placement, and the free starter
  Hatching Egg.** `ClaimHatchRules` now auto-assigns a freshly-hatched Baby to the first open
  `farmSlots` entry; `FeedDragonRules` (now takes `now`) auto-starts production on that slot when
  the 4th Feed transforms it to Adult — `AssignProducerTransaction` itself is unchanged, still
  available for future manual re-placement. New `Types.ProfileMeta.starterHatchGranted` (asymmetric
  default: `false` for a genuinely new profile, `true` for one missing the field entirely, so old
  saves aren't retroactively granted a bonus egg) plus new pure `StarterHatchRules.luau`, invoked
  directly from `init.server.luau` (not via `TransactionService` — no client payload). New
  `src/server/Services/FarmPlotSpawner.luau` builds each player's physical fenced Farm Plot
  (primitive-Part placeholder art); `DragonSpawner` now positions assigned dragons on their Farm
  Plot tile and respawns every owned dragon on rejoin, closing ADR-004's deferred world-presence
  gap for the Adult-on-slot case. See `adr/ADR-005-farm-plot-and-starter-hatch.md`.
- 2026-07-17 — **ADR-006: Production Egg inventory keyed by laying-dragon Rarity, and Sell
  Production Egg.** `Profile.productionEggInventory` changes shape from a flat
  `{Variant: count}` bucket to one such bucket per Rarity, so Sell can apply the GDD §8 formula
  (variant base value x laying dragon's rarity multiplier) correctly once a player owns dragons of
  more than one rarity; no migration for a pre-ADR-006 flat save (project is pre-launch, per direct
  user request not worth preserving) — it just reads back as an empty inventory instead of erroring.
  New `Variants.luau`; `ProductionConfig.variantOddsByRarity` (GDD §2 table) — `CollectNestRules`
  now rolls each produced egg's variant against the laying dragon's own rarity instead of always
  granting `Normal`. New `EggConfig.productionVariants.*.baseSellValue` (GDD §8: Mini 1/Normal
  2/Heavy 4/Giant 6/Golden 10). New `SellProductionEggRules`/`SellProductionEggTransaction`
  (`TransactionType.SellProductionEgg = 31`, already reserved; `TransactionCode.NothingToSell =
  48`) — GDD §8's "Sell all only," no selective selling. World-presence deferred, same split as
  items 5/6. See `adr/ADR-006-production-egg-rarity-inventory.md`.
