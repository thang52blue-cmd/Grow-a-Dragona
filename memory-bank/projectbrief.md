# Project Brief (foundation)

> Seeded 2026-07-14 from `Doc/Grow_a_Dragona_GDD.txt`, `README.md`, and `AGENTS.md`. Do not edit
> without explicit human instruction (AGENTS.md foundation-file rule).

## What it is

Grow-a-Dragona: a Roblox idle farm / gacha-collection game. Players hatch dragons, grow them from
Baby to Adult, collect the production eggs they lay, sell those eggs for Gold, and reinvest Gold (or
Robux) into rarer hatching eggs. A night-raid layer lets other players steal uncollected production
eggs, creating social tension around collection timing.

## Core pillars (GDD §1.2)

- **Passive Progression** — dragons produce eggs while offline; every login has something to collect.
- **Gacha Thrill** — rare dragons are genuinely hard to get; the hatch reveal moment must feel real.
- **Social Tension** — farms are not safe at night; uncollected eggs are at risk.
- **Collection Depth** — every hatched dragon is permanently owned and visible on the farm.

## MVP scope (AGENTS.md, GDD §8.1)

Build only:

- Gold, food, basic egg purchasing, timed hatching, dragon ownership, growth, and favorite state.
- Production assignment, nest collection, selling, display assignment, and simple derived synergy.
- Save/load, schema validation, session locking, idempotent transactions, and basic anti-cheat.
- Tests for pure domain logic and atomic economy/progression mutations.
- 5 elements (Fire, Water, Earth, Light, Dark), 5 rarities (Common → Mythic), plot expansion up to
  Level 4 (8 display slots) per GDD §8.1 — full Level 6 (12 slots) is a stretch, not a blocker.

Defer trading, breeding, clans, live events, complex raids (beyond a minimal steal/defend loop),
cross-server markets, and advanced monetization until the core loop is verified. See GDD §10 for the
full post-launch roadmap — none of it is in scope until the MVP loop is proven.

## Non-negotiables

- Server owns all valuable state; clients request actions and render approved results.
- No tunable balance value (prices, timings, odds, rates, bonuses) lives in code — see
  `memory-bank/techContext.md` (AGENTS.md hard rule; no ADR written for this yet).
