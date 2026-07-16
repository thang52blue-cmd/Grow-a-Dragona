# Active Context

> Always load. Current focus, last 3 done, current + next task. Overwrite this each `end-session`.

## Current focus

Backlog items 1, 2, 4, 5, 6 (Rules/Transaction layer), 10 (Food Shop), and 11 (Adult world-presence
+ Inventory breakdown) are complete. A Baby Dragon that reaches Adult now stays visible in the
Nursery as the Adult model (no more despawn-to-nothing), and the Inventory panel's Dragons line
breaks each Rarity down by Baby vs. Adult. **This overrides item 5's original "Adults get no world
presence until Farm Assignment" rule** (from `docs/prd/core-game-loop.md`'s Recommended MVP rule) —
per direct user request. The PRD doc itself is left unedited (saved-verbatim historical record);
actual game behavior now deliberately deviates from it. Farm-Slot-specific world-presence (item 6's
own follow-up: Adult+Nest models *once assigned to a slot*, Assign/Collect prompts) is still not
built — item 11 only covers the pre-assignment Nursery display.

## Last 3 done (2026-07-17 session, third part)

1. User asked (in Vietnamese) for two things: (a) show the Adult Dragon model in place after a
   Baby finishes its 4th Feed instead of despawning, with a note that an evolution animation might
   be added later (not this session), and (b) make the Inventory panel clearly show dragon counts
   broken down by Baby vs. Adult for easier MVP debugging.
2. Implemented: `DragonSpawner.Spawn` now branches on `dragon.GrowthStage`, cloning
   `ReplicatedStorage.DragonModels.Adult` (confirmed already staged in Studio, no new asset work)
   for an Adult, tagged `AdultDragon` (no `ProximityPrompt`, a `"{Element} Dragon (Adult)"`
   billboard). `RespawnAllBaby` renamed `RespawnAll`, filter changed to `AssignedSlotId == nil` so
   both Baby and not-yet-assigned Adult dragons reappear in the Nursery on rejoin.
   `init.server.luau`'s `FeedDragon` post-commit handler re-`Spawn`s instead of only despawning on
   `BecameAdult=true`. `EggInventoryUI.luau`'s dragon-count line now groups by
   `` `{Rarity} {Baby|Adult}` ``. No schema/ADR change (pure Runtime-only display). All 3 CI gates
   green (18 specs, unchanged — engine-glue/UI only).
3. Live-verified in Studio Play mode via the Roblox Studio MCP: fed a real `Baby_2` dragon to Adult
   via the `Transaction` remote, confirmed via `inspect_instance` the model swapped to the
   `AdultDragon` tag with no Feed prompt and the correct billboard text, screenshot-confirmed
   multiple Adults standing in the Nursery, and screenshot-confirmed the Inventory UI's new
   Baby/Adult breakdown line (`Common Baby x5, Common Adult x10, ...`). No console errors.

## Current task

Memory write-back for this session (this update). This work is **not yet committed** (items 6 and
10 from earlier today already were, in `a492c46` and `623bec9`).

## Next task

1. Ask the human whether to commit this Adult-world-presence/Inventory-breakdown work now (same
   "always ask before commit" pattern as the rest of today).
2. Backlog item 6's Farm-Slot-specific world-presence pass (Adult+Nest models once assigned,
   Assign/Collect prompts) is still open if the human wants to continue in priority order.
3. Item 7 (Sell Production Egg) is next after that; item 3 (engine-lane activation ADR) remains
   open/unblocked if the human wants to switch lanes.
4. An evolution animation on Baby→Adult transform was mentioned as a possible future addition —
   explicitly not part of this session, no animation exists yet (instant model swap only).
5. Food pricing (flat 10-gold placeholder from the earlier Food Shop session) still needs real
   balancing before ship.

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions — verify with `tasklist`/`curl localhost:34872/api/rojo` before assuming
it's up. Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"` prefixed before
`ci/*.sh` calls. Confirm new/changed files sync into the **Edit-mode** DataModel before starting
Play. The `Transaction` remote requires a numeric `requestId`.
`mcp__Roblox_Studio__user_mouse_input` (`instance_path`) + `screen_capture` reliably click-tests a
UI end-to-end; `inspect_instance` on a specific Workspace path (need the player's exact `UserId`,
e.g. `Workspace.Nursery.11039736402.5` — wildcard paths like `Nursery.*.5` are **not** supported)
is the reliable way to confirm world-model attributes/tags/children after a transaction.
