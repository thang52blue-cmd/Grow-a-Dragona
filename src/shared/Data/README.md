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
  switch and a single-request purchase cap; adjust once real balancing lands.
- `DragonConfig.json` — `elements` (food category + synergy type per element) and `rarities`
  (production multiplier per rarity) are transcribed from GDD §3.1-§3.2. Real design values.
- `FoodConfig.json` — the food-item catalog per element is transcribed from GDD §3.1's literal
  examples (e.g. Fire → chili peppers, hot sauce, fire berries). **Growth-rate numbers are
  deliberately absent** — the GDD only states qualitatively that feeding speeds growth and its
  absence "significantly" slows it, with no number given. Do not invent one; get it from a design
  decision (log it as an ADR when it lands) before Feed Dragon (backlog item 5) needs it.
- `EconomyConfig.json` — `startingGold: 0` because the GDD specifies a free starter egg, not a
  starting Gold amount (§2.1 step 1); 0 is the neutral default, not a sourced design value.
  `maxGold` and `maxInventoryStack` are engineering safety caps (keep numbers away from float-
  precision and DataStore edge cases), not GDD balance values.
