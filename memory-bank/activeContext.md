# Active Context

> Always load. Current focus, last 3 done, current + next task. Overwrite this each `end-session`.

## Current focus

Backlog items 1, 2, 4, and now 5 (fully done: Rules/Transaction + Phase B world-presence, both
live-verified) are complete. Hatching (item 4) is **instant** (`EggConfig.json` every tier's
`hatchDurationSeconds = 0`, per explicit user request) — see
`adr/ADR-002-hatch-state-and-dragon-schema.md`'s newest addendum. A player can now reach
`FeedDragonTransaction` in-game for real: Baby Dragons spawn in a shared `Workspace.Nursery`
placeholder area with a Feed `ProximityPrompt`, no direct-remote-call workaround needed anymore.
Adult Dragons still have no world presence — by design, per the plan doc's Recommended MVP rule
they only spawn once assigned to a Farm Slot (item 6).

**Everything for this backlog item was driven by the user-supplied plan doc, saved verbatim at
`docs/prd/core-game-loop.md`** — read that first before starting items 6/7 (Farm Assignment /
Production / Selling), which build directly on top of Phase B's Nursery pattern.

## Last 3 done (this session, 2026-07-16)

1. Implemented Feed Dragon (backlog item 5)'s Rules/Transaction layer and live-verified it
   end-to-end via the real `Transaction` remote (see `adr/ADR-003-feed-dragon-schema.md`);
   committed as `4b02518`/`ba0cf89`.
2. Made hatching instant per user request (`EggConfig.json` `hatchDurationSeconds = 0` for every
   tier); live-verified; committed as `6217185`.
3. Built and live-verified Phase B (world-presence) of backlog item 5: new
   `src/server/Services/DragonSpawner.luau` + `src/client/Dragon/FeedPromptController.luau` spawn a
   Baby Dragon model with a Feed `ProximityPrompt` in `Workspace.Nursery.<userId>` per non-Adult
   owned dragon, wired into `init.server.luau` (respawn on rejoin, spawn on Claim, update-or-despawn
   on Feed). Verified live in Studio Play mode: ~29 pre-existing dragons respawned correctly, a
   fresh dragon's model got a working prompt and `Fed 0/4` label, 4 real Feed calls advanced it
   `Baby_0→...→Adult` and despawned the model exactly on the 4th, a 5th feed rejected
   `DragonAlreadyAdult`, and a second dragon fed once stayed in the Nursery with its label/attribute
   live-updated to `Fed 1/4`. No console errors. Not yet committed (this session's work).

## Current task

Memory write-back for this session (this update), then commit Phase B.

## Next task

Backlog item 6 (Assign Producer / Collect Nest transactions) is next per priority order — needs its
own ADR for Farm Slot/Nest schema (deliberately not pre-approved by ADR-003). It should reuse
`DragonSpawner`'s Nursery-lane/tag/ProximityPrompt pattern for spawning the Adult Dragon + Nest once
assigned to a slot. Backlog item 3 (engine-lane activation ADR) remains open/unblocked if the human
wants to switch lanes instead.
