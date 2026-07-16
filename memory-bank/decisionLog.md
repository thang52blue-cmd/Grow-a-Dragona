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
