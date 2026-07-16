# Handoff

> Always load, read first. Last session's state transfer. Overwritten each `end-session`.

## Session: 2026-07-16 (continued) — Phase B: Baby Dragon world-presence, live-verified

**Verified state:** All three gates green: `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh
fast` → `PASSED` (14 specs, unchanged — this is engine-glue, no new pure Domain logic), `ci/lint.sh`
→ `PASSED`. **Live-verified in Studio Play mode via the Roblox Studio MCP.**

**What happened:**

1. User asked to restart the Rojo server (it wasn't running); restarted `rojo serve` in the
   background, confirmed it listens on `localhost:34872`.
2. User asked to continue unfinished work. Per `memory-bank/handoff.md`'s prior "Do next" list,
   picked Phase B of `docs/prd/core-game-loop.md`: Baby Dragon world-presence, the one remaining
   gap in backlog item 5 (a player still had no in-game way to reach `FeedDragonTransaction`).
3. Read the existing `HatchSpawner.luau`/`HatchCountdownController.luau`/`AutoClaimController.luau`
   pattern (world-visible hatching-egg decoration, tag-based client controllers, respawn-on-rejoin)
   and reused it directly rather than inventing a new one.
4. Implemented:
   - `src/server/Services/DragonSpawner.luau` — spawns a clone of
     `ReplicatedStorage.DragonModels.Baby` per non-Adult owned dragon into
     `Workspace.Nursery.<userId>` (a placeholder MVP location at `Vector3(60, 3, -40)`, one "lane"
     per player offset by 25 studs, chosen clear of `Workspace.SpawnLocation` and well within
     `Workspace.Baseplate`'s 2048×16×2048 bounds — confirmed via the Studio MCP's
     `inspect_instance` before picking the numbers). Each clone gets `DragonUID`/`Element`/
     `FeedCount` attributes, a `FeedPrompt` `ProximityPrompt` (`ActionText="Feed"`,
     `ObjectText="<Element> Dragon"`), and a `FeedStatus` billboard showing `Fed X/4`, and is tagged
     `BabyDragon` via `CollectionService`. `RespawnAllBaby`/`DespawnAll`/`Despawn`/
     `UpdateFeedCount` mirror `HatchSpawner`'s API shape.
   - `src/client/Dragon/FeedPromptController.luau` — connects every `BabyDragon`-tagged model's
     `ProximityPrompt.Triggered` to `Transaction:InvokeServer(requestId, TransactionType.FeedDragon,
     {DragonUID = ...})`, sending only `DragonUID` per the plan doc. Also listens to the existing
     `ProfileUpdated` snapshot (same one every other UI module already reads) to toggle the
     prompt's `ActionText` to `"Need Food"` when the player owns none of the dragon's Element's 3
     food items — purely presentational, never mutates persistent state.
   - Wired both into `init.server.luau`: `DragonSpawner.RespawnAllBaby` alongside
     `HatchSpawner.RespawnAllPending` on character load; `DragonSpawner.DespawnAll` alongside
     `HatchSpawner.DespawnAll` on `PlayerRemoving`; a successful `ClaimHatch` now also looks up the
     newly-committed dragon record (`profile.dragons[result.Data.DragonId]`, same key as
     `DragonUID`) and calls `DragonSpawner.Spawn`; a successful `FeedDragon` calls
     `DragonSpawner.Despawn` when `result.Data.BecameAdult` is true, otherwise
     `DragonSpawner.UpdateFeedCount`. Registered `FeedPromptController.Init` in
     `src/client/init.client.luau` next to the other controllers.
   - Deliberately did **not** spawn an Adult Dragon model on transform — per the plan doc's
     Recommended MVP rule, Adults get no world presence until assigned to a Farm Slot (backlog
     item 6), so the Baby model is simply despawned on `BecameAdult=true` and nothing replaces it
     yet.
5. Ran all 3 CI gates green (no new pure-Domain logic, so `ci/run-tests.sh fast` stayed at 14
   specs — this feature is entirely engine-glue by AGENTS.md's classification).
6. **Live-verified in Studio Play mode via the Roblox Studio MCP** (real client
   `Transaction:InvokeServer` calls, not a mocked path): started Play, drove Buy→Hatch→auto-Claim
   for a fresh Common egg from the Client datamodel, confirmed `Workspace.Nursery.<userId>` held
   ~29 Baby Dragon models (28 respawned from prior sessions' test dragons + the new one,
   `DragonUID=58`, `Element=Water`), each with a working `FeedPrompt` and `Fed 0/4` label. Granted
   test food, then fed dragon `58` four times via the real remote: `Baby_0→Baby_1→Baby_2→Baby_3→
   Adult`, and confirmed via `inspect_instance`/`search_game_tree` that the model was **despawned**
   from the Nursery exactly on the 4th call (`BecameAdult=true`); a 5th feed attempt on the same UID
   correctly rejected `DragonAlreadyAdult` (41). Fed a second, pre-existing dragon (`DragonUID=52`)
   once and confirmed it stayed in the Nursery with its `FeedStatus` label and `FeedCount` attribute
   live-updated to `Fed 1/4` (no despawn, correctly below Adult). `get_console_output` showed no
   game-code errors/warnings. Stopped Play mode afterward.
7. Updated `memory-bank/backlog.md` (item 5 now fully `~~DONE~~`), `activeContext.md`, and
   `progress.md` to record the above. This `handoff.md` write is the last step before commit.

**Deviations / judgment calls (not user-specified, worth restating):**
- The Nursery's exact world location/layout is an engineering placeholder — the plan doc only says
  "a temporary Nursery/Baby Area" and leaves the "Open Design Item" (exact location/capacity)
  unresolved; picked `Vector3(60, 3, -40)` with per-player lanes and a 5-wide grid purely so
  Baby Dragons don't all stack on top of each other, not because the GDD specifies these numbers.
- `FeedPromptController`'s "Need Food" hint reads `FoodConfig` client-side directly (already
  Studio-synced to `ReplicatedStorage.Shared.Data`, same pattern `EggShopUI`/`EggInventoryUI` use
  for `EggConfig`) rather than adding a new remote — it's read-only config data, not player state.
- Slot placement inside a player's Nursery lane is computed from `#folder:GetChildren()` at spawn
  time (not a stable per-dragon index) — acceptable for a temporary MVP area; a dragon transforming
  to Adult and despawning can leave a gap that's naturally backfilled by whichever dragon spawns
  next, no dedicated free-list needed at this scope.

**Do next:**
1. Backlog item 6 (Assign Producer / Collect Nest transactions) is next per priority order. Needs
   its own ADR for `FarmSlot`/Nest persistent schema (deliberately not pre-approved by ADR-003) —
   see `docs/prd/core-game-loop.md`'s `AssignProducerTransaction`/`ProductionService`/
   `CollectNestTransaction` sections and Phase D/E. Should reuse `DragonSpawner`'s Nursery-lane/
   tag/`ProximityPrompt` pattern for spawning the Adult Dragon + its Nest once assigned to a slot —
   `ReplicatedStorage.NestModels.Default` is already staged and ready to clone from (see
   `memory-bank/systemPatterns.md`).
2. Backlog item 3 (engine-lane activation ADR) remains open/unblocked if the human wants to switch
   lanes instead.
3. This session's Phase B work is **not yet committed** — commit it (new files:
   `src/server/Services/DragonSpawner.luau`, `src/client/Dragon/FeedPromptController.luau`; edited:
   `src/server/init.server.luau`, `src/client/init.client.luau`, and the memory-bank files above)
   before starting item 6.

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions/machine restarts — **verify with `tasklist`/`curl localhost:34872` before
assuming it's up**. Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"` prefixed
before `ci/*.sh` calls in this environment. The Studio MCP's `execute_luau` on the `Server`
datamodel does NOT reliably share Luau's `require()` module cache with the live running game —
don't trust ad-hoc server-side state dumps via MCP for anything beyond read-only sanity checks;
verify behavior through the actual remote/UI surface instead (this session again drove everything
through real `Transaction:InvokeServer` calls from the **Client** datamodel, reading results back
from `TransactionResult.Data`/`inspect_instance` on `Workspace`, never `execute_luau` on `Server`).
After editing a data/script file, don't press Play immediately — Rojo syncs into the **Edit-mode**
DataModel, and starting Play snapshots whatever the Edit-mode DataModel holds *at that moment*; if
the sync hasn't landed yet, Play starts with stale data and there's no error to signal it. Confirm
new files/values read back correctly in `Edit` datamodel via `search_game_tree`/`execute_luau`
first, *then* start Play (done this session: confirmed `DragonSpawner`/`FeedPromptController`
appeared under `ServerScriptService.Server.Services`/`StarterPlayer...Client.Dragon` in Edit mode
before starting Play).
