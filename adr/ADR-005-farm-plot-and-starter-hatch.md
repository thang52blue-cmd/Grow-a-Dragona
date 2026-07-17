# ADR-005: Farm Plot world-presence, auto Farm-Slot placement, and the free starter Hatching Egg

## Status

Accepted — 2026-07-17

## Context

The player directly requested the full first-join flow from `docs/GROW_A_DRAGONA_IMPLEMENTATION_GDD.md`
Section 1 be wired up end to end, plus "chưa setup farm plot nữa" (the Farm Plot itself still isn't
set up) with a physical fenced boundary and ground-tile slots. Three gaps stood between the
already-shipped transactions (items 4/5/6) and that flow:

1. **No physical Farm Plot exists.** `Profile.farmSlots` (ADR-004) is pure data; the only world
   geometry today is `DragonSpawner`'s ad-hoc "Nursery" holding lanes, not a fenced plot with
   slot-tiles tied to real `SlotId`s.
2. **Farm Slot assignment is manual-only and Adult-only.** `AssignProducerTransaction`
   (ADR-004) rejects any non-Adult dragon (`DragonNotAdult`) by design — a deliberate, tested,
   already-shipped gate. But the GDD's actual flow (§1, §9) auto-places a dragon into the first
   open slot **at hatch**, while still a Baby, and production starts automatically the moment it
   becomes Adult — no separate manual "assign" step for a dragon's first placement.
3. **No free starter egg.** The GDD (§1) grants a new player one free Hatching Egg, sitting
   physically on the plot, rolled at real Common-tier odds — nothing today grants Gold, eggs, or
   dragons on first join.

This touches already-shipped, tested contracts (`AssignProducerRules`'s Adult-only gate,
`ClaimHatchRules`, `FeedDragonRules`, `ProfileSchema`), so per `AGENTS.md`'s gated-actions rule this
gets its own ADR rather than a silent behavior change.

## Decision

- **`ClaimHatchRules.Stage`/`Commit`** now also auto-assigns the freshly-hatched dragon to the
  lowest-numbered open `farmSlots` entry (`AssignedSlotId` on the dragon, `AssignedDragonUID` on the
  slot), leaving `ProductionStartedAt = nil` since it's still a Baby. If every slot is already
  occupied, `AssignedSlotId` stays `nil` — the closest MVP equivalent of the GDD's "overflow to
  Storage" rule (Storage itself isn't built yet).
- **`FeedDragonRules.Stage`/`Commit`** gains a `now: number` parameter (previously didn't need the
  server clock) and, on the 4th Feed (`BecameAdult`), if the dragon already has an `AssignedSlotId`,
  sets that slot's `ProductionStartedAt = now` — production starts automatically, no client call to
  `AssignProducerTransaction` required for a dragon's first placement.
- **`AssignProducerTransaction` itself is unchanged** — its Adult-only/already-assigned/slot-empty
  checks stay exactly as shipped in ADR-004. It remains the path for any *future* manual
  re-placement (e.g. moving a dragon in from Storage once that exists), not for a dragon's initial
  hatch-time placement.
- **New `Types.ProfileMeta.starterHatchGranted: boolean`.** `ProfileSchema.default()` sets it
  `false` (a genuinely new profile hasn't gotten the free egg yet). `ProfileSchema.validate()`
  defaults a *missing* value to `true` instead of `false` — deliberately asymmetric, so a profile
  saved before this ADR (which already has real gold/dragons/progress) is never retroactively
  granted a surprise bonus egg; only profiles created via `.default()` after this change start
  eligible. A new pure `src/shared/Domain/StarterHatchRules.luau` (`ShouldGrant`/`Stage`/`Commit`)
  rolls the free egg's rarity from `EggConfig.hatchingTiers.Common.odds` — the same real odds a paid
  Common egg uses, per the GDD ("Same real odds as a paid starter-tier egg, not scripted") — and is
  invoked directly from `init.server.luau`'s `PlayerAdded` handler (not through
  `TransactionService`: there is no client payload to validate/dedupe, and it can only ever fire
  once per profile by construction).
- **New `src/server/Services/FarmPlotSpawner.luau`**: builds each player's physical Farm Plot —
  primitive-Part placeholder art (no Toolbox/Studio-authored fence or tile assets exist yet, unlike
  `DragonModels`/`EggModels`), a rectangular wood-plank tile per `farmSlots` entry, and a 4-beam
  wooden fence sized to fit them, matching the user's own description ("farm là vùng bao phủ bên
  ngoài dạng hàng rào, slot sẽ là từng ô đất bên trong"). `DragonSpawner.Spawn` now positions an
  already-assigned dragon on its Farm Plot tile instead of a Nursery lane; the Nursery lane logic is
  kept only as the fallback for a dragon with no slot (the overflow case above).

## Consequences

- Item 6's originally-deferred world-presence gap (see `adr/ADR-004-farm-slot-and-nest-schema.md`'s
  Consequences: "World-presence... is explicitly out of scope for this ADR and this pass") is now
  closed for the Adult-dragon-on-its-slot case, as a side effect of this pass — `DragonSpawner
  .RespawnAll` now respawns every owned dragon regardless of `AssignedSlotId`, and a manual
  `AssignProducerTransaction` call now also moves the dragon's world model (`init.server.luau`'s new
  `AssignProducer` post-commit branch).
- Nest world-presence (the actual egg-pile model, `Collect` `ProximityPrompt`) is **still** not
  built — only the Adult Dragon's own model appears at its slot. That remains a follow-up, same as
  before this ADR.
- The Farm Plot's fence/ground do not resize when more slots are added later — Plot Expansion
  (`memory-bank/backlog.md` item 13) will need to rebuild them, not just add tiles.
- `startingFarmSlots` is now `2` (see `src/shared/Data/README.md`'s 2026-07-17 update), so a brand
  new profile's Farm Plot is sized for exactly 2 tiles; `FarmPlotSpawner.EnsurePlot` sizes the
  fence/ground from whatever `slotIds` it's given, so it isn't hardcoded to that number.
- No Studio-side live verification has been done for this ADR's world-presence pieces (Farm Plot
  geometry, auto-placement, starter egg) — the Domain-layer logic is spec'd and green
  (`ci/run-tests.sh fast`), but a Roblox Studio MCP session was not available this pass; see
  `memory-bank/progress.md`'s entry for what still needs a manual Studio pass.
