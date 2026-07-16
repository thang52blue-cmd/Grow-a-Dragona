# Data

Tunables, synced by Rojo as plain `.json` files (Rojo turns a `.json` file into a `ModuleScript`
that returns the decoded table — confirmed against Rojo's own sync-details docs, not assumed).
Never hardcode these values in logic; require the file instead.

## Source of each value

- `EggConfig.json` — `hatchingTiers` (gold price + rarity odds per hatching-egg tier) and
  `productionVariants` (sell-value multiplier per production-egg variant) are transcribed verbatim
  from the GDD (`Doc/Grow_a_Dragona_GDD.txt` §4.2-§4.3). These are real design values, not
  placeholders. **Added 2026-07-15** for `BuyEggTransaction` (backlog item 2): each
  `hatchingTiers` entry also has `enabled` and `maxPurchaseAmount` — these two fields are
  engineering placeholders (not GDD-sourced), needed so the transaction has a per-tier on/off
  switch and a single-request purchase cap; adjust once real balancing lands. **Changed
  2026-07-16:** every tier's `hatchDurationSeconds` is now `0` (was a 5s-1800s placeholder ramp) —
  hatching is instant per explicit user request, matching `docs/prd/core-game-loop.md`. See
  `adr/ADR-002-hatch-state-and-dragon-schema.md`'s "hatching made instant" addendum.
- `DragonConfig.json` — `elements` (food category + synergy type per element) and `rarities`
  (production multiplier per rarity) are transcribed from GDD §3.1-§3.2. Real design values.
  **Added 2026-07-16** for Feed Dragon (backlog item 5): `elementOdds`, an equal-weight (20% each)
  placeholder used to roll a hatched dragon's `Element` — no real per-element rarity has been
  designed yet; see `adr/ADR-003-feed-dragon-schema.md`.
- `FoodConfig.json` — the food-item catalog per element is transcribed from GDD §3.1's literal
  examples (e.g. Fire → chili peppers, hot sauce, fire berries). The previously-flagged "no
  growth-rate number" gap is resolved by `docs/prd/core-game-loop.md`: growth is not rate-based at
  all — a Baby advances exactly one stage per successful Feed (any one owned food item matching the
  dragon's `Element`) and becomes Adult on the 4th, with no timers, decay, or partial progress. See
  `adr/ADR-003-feed-dragon-schema.md`.
- `EconomyConfig.json` — `startingGold: 0` because the GDD specifies a free starter egg, not a
  starting Gold amount (§2.1 step 1); 0 is the neutral default, not a sourced design value.
  `maxGold` and `maxInventoryStack` are engineering safety caps (keep numbers away from float-
  precision and DataStore edge cases), not GDD balance values.
- `ProductionConfig.json` — **Added 2026-07-17** for Farm Slot / Production (backlog item 6):
  `productionIntervalSeconds: 180` and `nestCapacity: 12` are transcribed verbatim from
  `docs/prd/core-game-loop.md`'s stated prototype numbers. `startingFarmSlots: 3` is an engineering
  placeholder (the PRD says "add unlocked production slots" but never specifies how many) — see
  `adr/ADR-004-farm-slot-and-nest-schema.md`.
