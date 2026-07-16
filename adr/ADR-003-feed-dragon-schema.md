# ADR-003: Feed Dragon schema (Element, GrowthStage, FeedCount)

## Status

Accepted — 2026-07-16

## Context

Backlog item 5 (Feed Dragon) needs `FeedDragonTransaction` implemented per
`docs/prd/core-game-loop.md` (user-supplied plan, pasted into chat 2026-07-16). ADR-002 already
flagged the blocker: `Types.DragonRecord` had `Rarity` only, no `Element`, and no config had
per-element roll odds — "Feed/Production features can use `Element`" was left as an explicit
follow-up.

This is gated per `AGENTS.md` ("Public save-schema and transaction-contract changes require
explicit approval and an ADR") since it adds new persistent fields to `Types.DragonRecord`. Scope
is deliberately limited to what backlog item 5 needs — Farm Slot / Nest / Production Egg schema
(backlog items 6-7, also described in the same plan doc) get their own ADR when those items are
actually implemented, not bundled in here.

## Decision

- `Types.DragonRecord` gains three fields:
  - `Element: Types.Element` — rolled once, at hatch time (`ClaimHatchRules.Stage`), via the same
    `WeightedRoll.pick` used for Rarity, against a new `DragonConfig.elementOdds` table (equal
    20%-each placeholder — no real per-element rarity has been designed; see
    `src/shared/Data/README.md`). Rolled independently from Rarity, using a second, independent
    server-side `math.random()` call — Element and Rarity are unrelated axes.
  - `GrowthStage: Types.GrowthStage` (`"Baby_0" | "Baby_1" | "Baby_2" | "Baby_3" | "Adult"`) —
    starts at `"Baby_0"` on hatch, advances exactly one stage per successful Feed, per the plan's
    state machine. Not rate-based, no timer, no offline growth — a plain discrete counter.
  - `FeedCount: number` (`0`-`4`) — starts at `0`; the 4th successful Feed sets `GrowthStage` to
    `"Adult"` in the same commit.
- **`WeightedRoll.pick` was generalized** from `(odds, rollValue)` (implicitly over
  `Rarities.List`) to `(orderedKeys, odds, rollValue)`, since Element rolling needed the identical
  cumulative-bucket algorithm over a different fixed list. A new `src/shared/Domain/Elements.luau`
  (`.List` + `.IsValid`) mirrors `Rarities.luau` for this purpose. All existing call sites
  (`ClaimHatchRules.luau`, its spec) were updated to pass `Rarities.List` explicitly; behavior for
  Rarity rolling is unchanged.
- **No new `FoodInventory` profile section.** The plan doc's `FoodInventory = {FireFood, ...}`
  bucket-per-element shape is not adopted — `Types.Profile.inventory` (`{[string]: number}`) is
  already generic and already holds hatching-egg items by string key (`BuyEggRules`). Food items
  reuse it directly, keyed by the concrete item name already defined in `FoodConfig.json` (e.g.
  `"ChiliPepper"`), via the existing `Inventory.add`/`Inventory.remove`. This is the same kind of
  deviation ADR-002/the Buy Egg session already made once (`EggTypeId` numeric id → reused
  `Rarity` string) — avoid a parallel bucket where a generic one already does the job.
- **Feed resolves "the matching food" as: the first item in `FoodConfig[dragon.Element]` (fixed
  3-item order) that the player currently owns at least 1 of.** The plan doesn't specify which of
  the 3 per-element food items is consumed when a player owns more than one kind; picking
  deterministically by config order (rather than e.g. cheapest/random) keeps `FeedDragonRules`
  pure and its spec deterministic. Revisit if the game later wants food-quality tiers to matter.
- **`AssignedSlotId` is deliberately NOT added yet.** It belongs to backlog item 6 (Farm
  Assignment)'s own schema decision, not this one.
- Backward compatibility: a `DragonRecord` saved before this ADR has none of these three fields.
  `ProfileSchema.validate` treats them the same as every other additive field in this codebase
  (`pendingHatches.Position`, `meta.nextEntityId`) — optional, defaulting to
  `Element="Fire"`, `GrowthStage="Baby_0"`, `FeedCount=0` rather than rejecting the profile. No
  forced migration, no schema-version bump.
- New `TransactionCode`s: `DragonNotFound = 40`, `DragonAlreadyAdult = 41`, `MissingFood = 42`
  (next free block after Hatching's 30-32). No separate "not owned" code — a player's dragons live
  only in their own `profile.dragons` map, so "doesn't exist" and "not owned by me" are the same
  case from `FeedDragonRules`'s point of view.

## Consequences

- `elementOdds` needs real balancing before shipping (tracked the same way as
  `hatchDurationSeconds` was — a placeholder, not a blocker for building the feature).
  `DragonConfig.rarities`/`.elements` (food type, synergy type) are unaffected.
  `DragonConfig.elements[element].foodType` (e.g. `"Spicy"`) is descriptive/flavor text only —
  `FoodConfig.json`'s per-element item list is the actual data `FeedDragonRules` validates against.
- Every dragon hatched from now on carries an `Element`; anything gated on `Element` (elemental
  synergy display bonuses, backlog item 8) is now unblocked.
- Farm Slot / Nest / Production Egg Inventory schema (items 6-7) still needs its own ADR when that
  work starts — this ADR does not pre-approve it.
