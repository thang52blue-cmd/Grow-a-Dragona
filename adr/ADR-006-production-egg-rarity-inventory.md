# ADR-006: Production Egg inventory keyed by laying-dragon Rarity, and Sell Production Egg

## Status

Accepted — 2026-07-17

## Context

Backlog item 7 (Sell Production Egg transaction) is next per priority order, and the user directly
asked to continue the production → collect → sell chain per
`docs/GROW_A_DRAGONA_IMPLEMENTATION_GDD.md` §2/§5/§7/§8. This is gated per `AGENTS.md` ("Public
save-schema and transaction-contract changes require explicit approval and an ADR") since it
changes the shape of an already-shipped persistent field. Approved by the human 2026-07-17 (this
session) before any schema code was written.

`adr/ADR-004-farm-slot-and-nest-schema.md` shipped `Profile.productionEggInventory` as a flat
`{ Normal, Mini, Heavy, Giant, Golden }` bucket, explicitly deferring both variant rolling (Collect
always granted `Normal`) and the question that ADR itself left open: "which egg records which
dragon laid it." The GDD's sell formula (§8) is `variant's base sell value x the laying dragon's
own rarity production multiplier` (Common 1x .. Mythic 100x) — a flat bucket with no rarity
attribution can't apply this correctly once a player owns dragons of more than one rarity, since
eggs from a Common and a Mythic dragon would be indistinguishable once collected.

## Decision

- `Types.ProductionEggInventoryByRarity = { [Rarity]: ProductionEggInventory }` — one
  `{ Normal, Mini, Heavy, Giant, Golden }` bucket per Rarity (all 5 always present, zero-filled).
  `Profile.productionEggInventory`'s type changes from `ProductionEggInventory` to this nested
  type. Chosen over the alternative of valuing each egg at collection time and storing only a
  gold total, because the GDD's sell screen (§8) itemizes "how many of each variant... what each
  is worth" — keeping counts (not pre-converted gold) preserves that breakdown, and because the
  variant/rarity key space is small and fixed (5x5), a nested table stays simple and trivially
  validated, same reasoning ADR-004 already used for choosing a dedicated typed table over the
  generic `Profile.inventory` bucket.
- **No migration for the old flat shape.** A `Profile` saved under ADR-004 has the old flat
  `{Variant: count}` shape; `ProfileSchema.validate` does not special-case or migrate it — since
  this project is pre-launch, every existing save is dev/test data, and the human explicitly said
  not to bother preserving it (delete-if-needed is fine). `validate` only ever reads
  `productionEggInventory` by Rarity-named keys now, so an old flat save's top-level Variant-named
  keys simply aren't recognized and that profile's Production Egg inventory reads as empty (all
  buckets zero) rather than erroring or being specially carried over. New saves and any
  already-nested shape validate per-Rarity/per-Variant as normal.
- New `src/shared/Domain/Variants.luau` (`List`/`IsValid`), mirroring `Rarities.luau`/
  `Elements.luau` exactly, so `CollectNestRules` and `SellProductionEggRules` share one canonical
  variant order instead of repeating a literal list.
- `ProductionConfig.json` gains `variantOddsByRarity: { [Rarity]: { [Variant]: number } }`,
  transcribed verbatim from the GDD §2 table (e.g. Common: Normal 60%/Mini 25%/Heavy 10%/Giant
  4%/Golden 1%; Mythic: Normal 10%/Mini 5%/Heavy 30%/Giant 35%/Golden 20%). `CollectNestRules.Stage`
  now rolls each newly-produced egg's variant against the *laying* dragon's own Rarity odds via
  the existing generalized `WeightedRoll.pick`, taking an externally-supplied
  `variantRollValues: { number }` array (same "caller injects `math.random()`, pure code never
  calls it" precedent as every prior roll in this codebase) sized to `nestCapacity` so the caller
  never needs to know `eggsCollected` in advance. `CollectNestTransaction`'s result shape changes
  from a single `Variant = "Normal"` field to `VariantCounts: { [Variant]: number }`, since one
  Collect can now yield a mix of variants.
- `EggConfig.json`'s `productionVariants` entries gain a concrete `baseSellValue` (Mini 1, Normal
  2, Heavy 4, Giant 6, Golden 10 — GDD §8's table, derived from the existing `goldMultiplier x 2`
  but stored as the already-rounded whole number rather than computed at runtime, avoiding float
  rounding). `goldMultiplier` is left in place, unused by the new sell math but kept as the
  already-documented source those numbers were derived from.
- New `src/shared/Domain/SellProductionEggRules.luau` + `SellProductionEggTransaction.luau`
  (`TransactionType.SellProductionEgg = 31`, already reserved by ADR-004). Per GDD §8 ("Only Sell
  all - no selective selling"), the payload carries no fields; `Stage` walks every
  `(Rarity, Variant)` bucket, values each non-empty one, sums to `TotalGold`, and rejects
  `TransactionCode.NothingToSell` (new code, `48`) if the whole inventory is empty rather than
  silently succeeding for 0 gold. `Commit` grants Gold (capped at `EconomyConfig.maxGold`, same as
  every other Gold grant) and clears the entire `productionEggInventory` back to all-zero in one
  shot.

## Consequences

- `SellProductionEggRules`'s `SoldLineItem` array (`{Rarity, Variant, Count, UnitValue, Subtotal}`)
  gives the future sell-screen UI everything it needs for GDD §8's itemized breakdown without
  another schema pass.
- World-presence for all three of production/collect/sell (the Nest egg-pile model, a Collect
  `ProximityPrompt`, and a market-stall Sell prompt/UI) is explicitly **out of scope for this ADR**
  — same Rules/Transaction-then-world-presence split already used for backlog items 5 and 6.
- No "remove eggs without selling" or partial-sell transaction exists — matches the GDD's own
  "Sell all only" design, so none was built.
- A future Earth-element synergy pass (GDD §2's closing note: "Earth synergy... stacks on top of
  these [variant odds] as an additional shift") will need to adjust the odds `CollectNestRules`
  rolls against, but that adjustment is additive to this ADR's shape, not a further schema change.
