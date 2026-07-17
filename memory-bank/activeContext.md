# Active Context

> Always load. Current focus, last 3 done, current + next task. Overwrite this each `end-session`.

## Current focus

Backlog items 1, 2, 4, 5, 6, 7 (Rules/Transaction layer + world-presence), 10 (Food Shop), 11 (Adult
world-presence + full dragon-detail display), 12 (ClearTestDragons harness), and 14 (Farm Plot
world-presence + entrance fix + dragon ground-anchor fix) are complete. Item 7 (Sell Production Egg)
shipped this session per `adr/ADR-006-production-egg-rarity-inventory.md` — `productionEggInventory`
is now nested by the laying dragon's Rarity, `CollectNestRules` rolls real variants (GDD §2 odds),
and `SellProductionEggRules`/`SellProductionEggTransaction` sell the whole inventory at once (GDD §8
pricing). World-presence for the whole production→collect→sell chain (Nest egg-pile model, Collect
`ProximityPrompt`, market-stall Sell prompt) is now also built and live-verified — see backlog items
6/7's "later same day" updates. Still not built: GDD §9's slot-picker/Assign walk-up UI (Farm Slots
still only ever get assigned automatically, never manually via a world interaction) and a rich
itemized Sell-screen UI (this pass's Sell prompt fires directly, no confirmation screen).

## Last 3 done (2026-07-17 session, eighth part)

1. Built world-presence for the Nest/Collect/Sell chain per direct follow-up user request. New
   `src/server/Services/NestSpawner.luau` (clones the already-staged
   `ReplicatedStorage.NestModels.Default`, up to 5 placeholder egg-pile Parts + counter badge,
   Collect `ProximityPrompt`) and `MarketStallSpawner.luau` (placeholder table+awning stall +
   Sell `ProximityPrompt`); new client `CollectPromptController.luau`/`SellPromptController.luau`
   mirror `FeedPromptController`'s direct Trigger→`Transaction:InvokeServer` pattern. Added a 15s
   background loop in `init.server.luau` that re-runs `ProductionRules.Advance` (bookkeeping-only,
   grants nothing) so a Nest's pile visibly grows between Collects, not just right after a
   transaction. 21 specs unchanged (engine-glue only), compile/lint green.
2. **Live-verified cleanly in Studio this time** (unlike the previous part's inconclusive attempt):
   3 real Nests spawned matching 3 already-Adult-assigned Farm Slots, each with a correctly-capped
   5-egg pile and a live counter badge (`x7`, `x12`); a real Collect via `Transaction:InvokeServer`
   emptied the pile and disabled the prompt/badge immediately; a real Sell via the Market Stall's
   `{}` payload returned a correct itemized `SoldLineItems` breakdown across 2 rarities × 4 variants
   summing to the right `TotalGold`. No console errors. See backlog item 7's update for exact
   numbers.
3. This time, avoided the previous part's `DataService.Load` diagnostic pitfall entirely — used
   only structural `Workspace` reads (nest/badge/prompt state) plus real client remote calls to
   verify, per the environment-note lesson recorded last part.

## Earlier this session (seventh part)

1. Fixed two live bugs the user reported: the Farm Plot's own `Ground` Part was z-fighting with
   `Workspace.Baseplate` (both green, same Y=0) causing a flickering floor — removed the `Ground`
   Part entirely (`FarmPlotSpawner.luau`), fence/tiles are enough, Baseplate is the floor. Dragon
   world models were placed at a guessed fixed Y offset instead of their real geometry, sinking an
   Adult model ~5 studs into the ground — added `DragonSpawner.placeModelOnGround` (measures each
   model's actual `GetBoundingBox()` and rests its true bottom exactly on the target surface Y,
   works for any model size/pivot). Live-verified in Studio: fence has a genuine walkable gap at
   the spawn-facing side (8-stud, centered), and a live Adult dragon's measured bounding-box bottom
   sat exactly at Y=0.5 (the Farm Slot tile's top surface), not sunk/floating.
2. Implemented backlog item 7 (Sell Production Egg) plus the two prerequisites it needed: variant
   odds when collecting (`ProductionConfig.variantOddsByRarity`, GDD §2) and a schema change so
   `productionEggInventory` tracks which dragon Rarity laid each egg (`adr/ADR-006-...`, approved by
   the user before writing schema code, per `AGENTS.md`'s hard rule). New `Variants.luau`,
   `SellProductionEggRules.luau`/`.spec.luau`, `SellProductionEggTransaction.luau`. No migration
   for `ProfileSchema`'s legacy flat-shape saves — per direct follow-up user request (project is
   pre-launch dev data, not worth preserving), a pre-ADR-006 flat save now just reads back as an
   empty Production Egg inventory instead of being carried over. 21 specs passing (up from 19),
   compile/lint green.
3. Attempted a live Studio pass for item 7 via the real `Transaction:InvokeServer` remote (Collect
   on a Common-dragon slot and an Epic-dragon slot both returned correct-looking `VariantCounts`),
   but a manual `DataService.Load(userId, "diagnostic-job")` I ran mid-pass (to work around an
   earlier `DataService.Get` returning `nil`) left the session in an inconsistent state afterward
   (a follow-up read showed the Epic bucket still zero, `PlayerRuntimeStore.Get` returning `nil`) —
   attributed to that diagnostic probe interfering with the real session lock, not confirmed as a
   code defect (see backlog item 7's note). **Needs a clean live Studio pass next session with no
   manual `DataService` calls.**

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
(`623bec9`) is committed yet — everything from the full-detail display upgrade through today's
farm-fix/Sell-Production-Egg/Nest-Collect-Sell-world-presence work is still uncommitted, and the
user explicitly said "not now" once already this session (right after the full-detail upgrade) —
**ask before committing each time, don't assume yes.**

## Next task

1. Ask the human whether to commit everything uncommitted now.
2. GDD §9's Assign/placement walk-up UI (tap an empty slot, pick from storage) is still not built —
   Farm Slots today only ever get assigned automatically (ClaimHatch/FeedDragon's auto-placement);
   `AssignProducerTransaction` itself works and is spec/live-verified, it just has no world-trigger
   yet, unlike Collect/Sell which now do.
3. A rich itemized Sell-screen UI (GDD §8) isn't built — this pass's Sell prompt fires directly
   like Feed/Collect, no confirmation/breakdown screen before the sale happens.
4. `AddTestDragon` still doesn't spawn a Nursery model for the Adult it grants (only dragons that
   go through `ClaimHatch`/`FeedDragon`'s post-commit `Spawn` call get one) — noticed earlier this
   week, not fixed (out of scope for what was asked; only matters for manual testing via that
   specific harness, not real gameplay).
5. Evolution animation on Baby→Adult transform remains a "maybe later" idea, not implemented.
6. Food pricing (flat 10-gold placeholder) still needs real balancing before ship.
7. Item 3 (engine-lane activation ADR) remains open/unblocked whenever picked up.

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions — verify with `tasklist`/`curl localhost:34872/api/rojo` before assuming
it's up. Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"` prefixed before
`ci/*.sh` calls. Confirm changed files sync into the **Edit-mode** DataModel before starting Play.
`inspect_instance`/`execute_luau` need the exact `Workspace` path with the player's literal numeric
`UserId` — no wildcard segments. `mcp__Roblox_Studio__get_studio_state` can report `Play` mode
still active from a previous turn even after this session called `start_stop_play(false)` earlier
in the conversation — always re-check state rather than assuming Stop persisted across long gaps.
**New this session:** the `Transaction` RemoteFunction's real argument order is
`InvokeServer(requestId: number, typeId: number, payload)`, and `requestId` must be a
`PayloadValidator.IsPositiveInteger` (a plain incrementing number is fine) — a string requestId
silently fails `InvalidRequest` (code 1) with no other clue. Do **not** call
`DataService.Load(userId, someArbitraryJobId)` directly from `execute_luau` as a workaround when
`DataService.Get` returns `nil` for an already-joined player — its session-lock claim can race the
real `PlayerAdded` flow and leave `PlayerRuntimeStore` in a broken state for the rest of that Play
session (this happened this session and was never fully root-caused). If `DataService.Get` returns
`nil` for a player who should already have a profile, stop and re-check Play/PlayerAdded state
first rather than forcing a fresh Load.
