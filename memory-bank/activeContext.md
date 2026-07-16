# Active Context

> Always load. Current focus, last 3 done, current + next task. Overwrite this each `end-session`.

## Current focus

Backlog items 1, 2, 4, 5, 6 (Rules/Transaction layer), 10 (Food Shop), 11 (Adult world-presence +
full dragon-detail display), and 12 (ClearTestDragons harness) are complete. Every place a dragon
is displayed (Nursery billboard, Inventory panel) now shows Rarity + Element + exact GrowthStage
(e.g. `"Rare Fire - Baby_1 (Fed 1/4)"`, `"Common Fire Adult x1"`), not just a coarse Baby/Adult
bucket — per direct follow-up user request for full MVP debug info. `ClearTestDragons` now has a
client "Clear Dragons" test button (was remote-only before). Farm-Slot-specific world-presence
(item 6's own follow-up: Adult+Nest models *once assigned to a slot*, Assign/Collect prompts) is
still not built.

## Last 3 done (2026-07-17 session, sixth part)

1. User asked for a client-side test button to fire `ClearTestDragons` (previously only callable
   via `execute_luau`). Added `makeButton("ClearDragonsButton", "Clear Dragons", 3,
   "ClearTestDragons")` in `src/client/init.client.luau`, same row as the existing gold test
   buttons. All 3 CI gates green.
2. Live-verified in Studio: granted 4 test dragons, screenshotted the Nursery with all 4 visible
   (confirming the full-detail labels from the previous part still read correctly, e.g. "Rare Fire
   - Baby_1 (Fed 1/4)"), clicked the real button via simulated mouse input, screenshotted again —
   all 4 models vanished instantly — and confirmed via `execute_luau` the dragon count dropped to
   0. No console errors.

## Earlier this session (fifth part)

1. User asked to clear all of the test player's dragons to restart testing. Added
   `ClearTestDragons` debug remote (`RemotesSetup.luau` + `init.server.luau`, same pattern as
   `AddTestFood`/`AddTestDragon`): wipes `profile.dragons`, resets every `profile.farmSlots` entry
   to empty, despawns the Nursery. Live-verified: dragon count → 0, Nursery → 0 children, a
   deleted dragon UID correctly returns `DragonNotFound` on Assign. Fixed one `selene`
   unused-variable warning.
2. User then asked for full dragon info everywhere it's displayed — Rarity, Element, and growth
   stage — for easier debugging. Upgraded `DragonSpawner`'s world billboard from a bare `Fed X/4` /
   `"{Element} Dragon (Adult)"` to `"{Rarity} {Element} - {GrowthStage} (Fed X/4)"` /
   `"{Rarity} {Element} - Adult"` (new `Rarity`/`GrowthStage` `SetAttribute`s so `UpdateFeedCount`
   can rebuild the label without needing the full record passed back in); the Feed
   `ProximityPrompt`'s `ObjectText` also gained `Rarity`.
3. `EggInventoryUI.luau`'s dragon-count line upgraded from `` `{Rarity} {Baby|Adult}` `` to
   `` `{Rarity} {Element} {GrowthStage}` `` (full detail, e.g. `Common Fire Adult x1, Rare Fire
   Baby_1 x1`); bumped `inventoryFrame`/`dragonsLabel` height to fit more lines. All 3 CI gates
   green (18 specs, unchanged). Live-verified in Studio: hatched+fed a fresh Rare Fire dragon,
   read its exact billboard text via `execute_luau` (`"Rare Fire - Baby_1 (Fed 1/4)"`), and
   screenshot-confirmed the Inventory UI's full-detail breakdown. No console errors.

## Current task

Memory write-back for this session (this update). None of today's work since the Food Shop commit
(`623bec9`) is committed yet — the Adult-world-presence/Inventory-breakdown commit (`ebb2c87`)
predates the full-detail upgrade, `ClearTestDragons`, and its new client button, all three still
uncommitted, and the user explicitly said "not now" once already this session (right after the
full-detail upgrade) — **ask before committing each time, don't assume yes.**

## Next task

1. Ask the human whether to commit everything uncommitted now (full-detail display upgrade +
   `ClearTestDragons` + its client button).
2. Backlog item 6's Farm-Slot-specific world-presence pass is still open if the human wants to
   continue in priority order.
3. Item 7 (Sell Production Egg) is next after that; item 3 remains open/unblocked otherwise.
4. `AddTestDragon` still doesn't spawn a Nursery model for the Adult it grants (only dragons that
   go through `ClaimHatch`/`FeedDragon`'s post-commit `Spawn` call get one) — noticed this session,
   not fixed (out of scope for what was asked; only matters for manual testing via that specific
   harness, not real gameplay).
5. Evolution animation on Baby→Adult transform remains a "maybe later" idea, not implemented.
6. Food pricing (flat 10-gold placeholder) still needs real balancing before ship.

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions — verify with `tasklist`/`curl localhost:34872/api/rojo` before assuming
it's up. Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"` prefixed before
`ci/*.sh` calls. Confirm changed files sync into the **Edit-mode** DataModel before starting Play.
`inspect_instance`/`execute_luau` need the exact `Workspace` path with the player's literal numeric
`UserId` — no wildcard segments. `mcp__Roblox_Studio__get_studio_state` can report `Play` mode
still active from a previous turn even after this session called `start_stop_play(false)` earlier
in the conversation — always re-check state rather than assuming Stop persisted across long gaps.
