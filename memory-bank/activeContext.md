# Active Context

> Always load. Current focus, last 3 done, current + next task. Overwrite this each `end-session`.

## Current focus

Backlog items 1, 2, 4, and now 5 (Rules/Transaction + live verify) are done. Item 5 still has one
gap: **no world-presence** — no Nursery, no Baby Dragon spawn, no Feed `ProximityPrompt` — so a
real player has no in-game way to reach `FeedDragonTransaction` yet, only via a direct remote call
(which is how this session verified it). MVP placeholder 3D assets for Dragon (Baby/Adult) and
Nest are already staged in `ReplicatedStorage.DragonModels`/`NestModels` (Studio-side, not
git-tracked — see `memory-bank/systemPatterns.md`), ready for whoever builds Phase B to clone from.

**Everything for this backlog item is driven by the user-supplied plan doc, saved verbatim at
`docs/prd/core-game-loop.md`** — read that first before continuing item 5's Phase B, or items 6/7.

## Last 3 done (this session, 2026-07-16)

1. Implemented Feed Dragon (backlog item 5)'s Rules/Transaction layer: `adr/ADR-003-feed-dragon-
   schema.md` (DragonRecord gains Element/GrowthStage/FeedCount; Element now rolled at hatch via a
   generalized `WeightedRoll.pick` + new `Elements.luau`; Food reuses the existing generic
   `Profile.inventory`); new `FeedDragonRules.luau`+spec (10 cases) and thin
   `FeedDragonTransaction.luau` wired into `TransactionService`. All 3 CI gates green (14 specs).
   Committed as `4b02518`.
2. Found `rojo serve` wasn't running (stale Studio sync dialog); restarted it, user reconnected
   Studio ("đã kết nối thành công").
3. Live-verified `FeedDragonTransaction` in Studio Play mode via the Roblox Studio MCP, driving a
   real client through real remotes (not a mocked path): Buy→Hatch→auto-Claim→Feed×4 on a fresh
   Common/Earth dragon behaved exactly per spec (one food consumed per Feed, one GrowthStage per
   Feed, Adult on the 4th, `DragonAlreadyAdult`/`DragonNotFound`/`InvalidRequest` all rejected
   correctly), no console errors. Had to add a permanent `AddTestFood` remote (mirrors the existing
   `AddTestGold` test-harness pattern) since there was no way to grant Food otherwise — Buy Food
   isn't a designed transaction. This is now committed too.

## Current task

Memory write-back for this session (this update).

## Next task

Phase B of `docs/prd/core-game-loop.md`: a temporary Nursery/Baby-Area, spawning a Baby Dragon
model (clone `ReplicatedStorage.DragonModels.Baby`) per hatched dragon, and a Feed
`ProximityPrompt` that sends only `DragonUID` to the server — this is what actually lets a player
reach `FeedDragonTransaction` in-game. Alternatively, backlog item 3 (engine-lane activation ADR)
or item 6 (Assign Producer / Collect Nest) are open if the human wants to switch lanes; item 6 will
need its own ADR for Farm Slot / Nest schema (deliberately not pre-approved by ADR-003).
