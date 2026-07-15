# Shared vocabulary

> Always load, keep tight. Decode jargon; use these exact names in code and specs. Add a term here
> the moment `workflow: grill` coins or clarifies it — don't let two names drift for one concept.

| Term | Meaning |
|---|---|
| Gold | The single core currency (GDD §4.1). Not the same as Dragon Gems. |
| Dragon Gems | Cosmetic-only currency from selling duplicate dragons (GDD §7.3). Out of MVP scope. |
| Hatching Egg | Purchased from the shop with Gold or Robux; the only source of new dragons (GDD §4.1, §4.3). Has a rarity-odds table per tier. |
| Production Egg | Laid passively by an Adult dragon; collected and sold for Gold (GDD §4.2). Never confuse with Hatching Egg — they are opposite ends of the loop. |
| Egg Variant | A Production Egg's sell-value multiplier: Normal/Mini/Heavy/Giant/Golden (GDD §4.2). Distinct from Hatching Egg tier and from dragon Rarity. |
| Element | One of Fire, Water, Earth, Light, Dark (GDD §3.1). Fixes a dragon's food type and synergy bonus. Light and Dark are intentionally rarer within a tier. |
| Rarity | One of Common, Rare, Epic, Legendary, Mythic (GDD §3.2). Set exclusively by the gacha roll on hatch; never chosen or inferred elsewhere. |
| Baby / Adult | Dragon growth stage (GDD §3.3). Only Adults produce eggs. |
| Synergy | The bonus from having ≥2 same-element dragons in display slots simultaneously (GDD §3.4). Scales with count; recalculated, never saved. |
| Mascota | The one equipped dragon that follows the player and has an active role in raids (GDD §3.5, §6.5). |
| Plot | A player's farm — physical space, display slots, expandable (GDD §5.1-§5.2). |
| Display slot vs. Storage | Display slots produce and count toward synergy; Storage is unlimited but inert (GDD §5.3). |
| Night Raid | Other players can enter a farm at night and steal uncollected Production Eggs; Dark-dragon synergy is the passive defense (GDD §6). MVP scope is a minimal steal/defend loop, not the full roadmap version. |
| Luck Boost | Consumable that temporarily raises gacha odds; stacks (GDD §4.4). |
| Atomic Write Set | The single commit that applies every field change for one transaction — see `memory-bank/systemPatterns.md`. |
| Session lock | Server-held lock proving a profile isn't being mutated from two places at once; checked before every transaction. |

No entries yet from a `workflow: grill` session — this file was seeded from the GDD/README on
2026-07-14. Update it as real feature-alignment conversations happen.
