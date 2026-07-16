# Handoff

> Always load, read first. Last session's state transfer. Overwritten each `end-session`.

## Session: 2026-07-16 — Core-loop plan received; MVP assets sourced; Feed Dragon (backlog item 5) Rules/Transaction built

**Verified state:** All three gates green: `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh
fast` → `PASSED` (14 specs, up from 12), `ci/lint.sh` → `PASSED`. **Not live-verified in Studio
this session** — `rojo serve` was found not running (Studio's sync dialog showed "synced 1 day
ago"); it was restarted in the background but the human hasn't reconnected Studio to it yet, so
`FeedDragonTransaction` has only been proven at the pure-spec layer, not exercised live.

**What happened:**

1. The user pasted a new gameplay plan (English) for the full core loop: Buy Egg → Hatch → Baby
   Dragon → Feed ×4 → Adult → auto-produce Production Eggs in a capped (12) Nest → Collect → Sell →
   repeat. Saved verbatim as `docs/prd/core-game-loop.md` (this is now the source-of-truth spec for
   backlog items 5-7 — read it before touching any of them). Cross-checked it against the existing
   repo/ADRs and flagged two things to the user before implementing: (a) dragons don't roll an
   `Element` yet (a known ADR-002 blocker), and (b) the plan needs new persistent `DragonRecord`
   fields, which is a gated save-schema change per `AGENTS.md`.
2. User asked what 3D assets were needed and said to connect to Roblox Studio and source them.
   Used the Studio MCP (`search_asset`/`insert_asset`/`inspect_instance`/`screen_capture`) to find
   free Creator Store models for Baby Dragon, Adult Dragon, and Nest. **Rejected several candidates
   after inspection:** one "Green Dragon" boss-rig model had embedded combat/AI `Script`s
   (`EXP`/`Gold`/`ProjectileMagic`/`Respawn`/etc. — a whole enemy system, not a clean asset); one
   was a single flat un-dragon-shaped `Part`; one had near-zero mesh size (broken/degenerate). This
   repeats the exact lesson from ADR-002's `CoreSkyboxSystem` incident: never trust an imported
   free model's contents without reading them first. **Kept:** one dragon mesh (Creator Store asset
   `17597495724`, "AN_Dragon" by LordCat76, free, script-free) cloned twice via `Model:ScaleTo()`
   into `ReplicatedStorage.DragonModels.Adult` (~11×12×10 studs) and `.Baby` (~4×4×3 studs, scale
   0.033) so both stages share one consistent look; one nest mesh (asset `488637788`, "Bird's Nest"
   by LegendaryFrosts, free, script-free) into `ReplicatedStorage.NestModels.Default`. Judged Food
   items don't need 3D models at all for MVP (UI-icon only, per the plan). Documented the exact
   asset IDs/rejections in `memory-bank/systemPatterns.md`'s new "World-model asset locations"
   section (this is Studio-side state, not git-tracked, same as the pre-existing `EggModels`).
   `Workspace.AssetPreview` currently holds a live side-by-side preview of the 3 kept models — the
   user confirmed via screenshot that they look right ("these models are pretty, continue").
3. User said to continue. Ran `ci/gate-freshness.sh`/`compile-check.sh`/`run-tests.sh fast` first
   to confirm a known-green baseline (12 specs, all passing) before starting new work.
4. Wrote `adr/ADR-003-feed-dragon-schema.md` (append-only entry added to `decisionLog.md`) covering:
   `DragonRecord` gains `Element`/`GrowthStage`/`FeedCount`; `Element` rolled at hatch via a newly
   *generalized* `WeightedRoll.pick` (was hardcoded to `Rarities.List`, now takes an explicit
   ordered-key-list parameter so it works for both Rarity and the new `Elements.luau`); a
   placeholder equal-weight (20% each) `DragonConfig.elementOdds`, same "explicit placeholder,
   not a blocker" precedent as `hatchDurationSeconds`; **no new `FoodInventory` profile section** —
   Food reuses the existing generic `Profile.inventory` (same deviation pattern as
   `EggTypeId`→`Rarity` from the Buy Egg session); `AssignedSlotId` deliberately deferred to
   whichever ADR covers backlog item 6 (Farm Assignment).
5. Implemented the vertical slice: `Elements.luau` (+spec, mirrors `Rarities.luau`);
   `WeightedRoll.luau` generalized (+spec updated, one new case for a non-Rarity key list);
   `ClaimHatchRules.luau` updated to also roll `Element` and initialize `GrowthStage`/`FeedCount`
   (+spec updated with new assertions); `ProfileSchema.luau` validates/defaults the 3 new
   `DragonRecord` fields the same additive way as `pendingHatches.Position` (+2 new spec cases: one
   for the default path, one rejecting invalid Element/GrowthStage/negative-or-fractional
   FeedCount); new `FeedDragonRules.luau` (+spec, 10 cases: success + stage-advance, food-priority-
   order consumption, 4th-feed-transforms-exactly-once, missing-food ×2, already-Adult ×2 (incl.
   duplicate-request), unknown-dragon, malformed-payload, Stage-doesn't-mutate); new thin
   `src/server/Transactions/Dragon/FeedDragonTransaction.luau`, registered in `init.server.luau`
   under the already-reserved `TransactionType.FeedDragon` (30) with a 10-req/2s rate limit, same
   pattern as every prior transaction. New `TransactionCode`s: `DragonNotFound=40`,
   `DragonAlreadyAdult=41`, `MissingFood=42`.
6. Ran `ci/compile-check.sh` (hit and fixed one real error: `ProfileSchema.luau`'s dragons-clone
   literal was missing the 3 new required `DragonRecord` fields, caught by `luau-lsp analyze`'s
   structural typing), `ci/run-tests.sh fast` (14/14 green), `ci/lint.sh` (found and fixed stylua
   formatting diffs — some pre-existing in files this session didn't touch, cleaned up anyway since
   `stylua src` is a zero-risk mechanical pass).
7. Attempted live Studio verification per the established precedent (every prior backlog item was
   live-verified via the Studio MCP before being marked DONE). Found `rojo serve` was **not
   running** (`tasklist` showed no process, `curl localhost:34872` refused) — meaning Studio's copy
   of the code was still the old, pre-session version despite the asset work from step 2 having
   landed fine (that was done directly via `execute_luau`, independent of Rojo sync). Restarted
   `rojo serve` in the background. Deliberately **did not** attempt to click Studio's "Connect"
   button via simulated input — that's a UI action on the user's own live/shared Studio session,
   better left to them or a future turn with explicit confirmation, rather than blindly automating
   a click. **Backlog item 5 is therefore marked "Rules/Transaction done, live verify pending" in
   `memory-bank/backlog.md`, not fully DONE** — this is a deliberate, honest gap, not an oversight.

**Deviations from the plan doc** (see `adr/ADR-003-feed-dragon-schema.md` for full reasoning):
- No `FoodInventory = {FireFood, WaterFood, ...}` bucket — reused the existing generic
  `Profile.inventory`, keyed by the concrete `FoodConfig.json` item names.
- `AssignedSlotId` not added to `DragonRecord` yet — that's backlog item 6's schema decision.
- The plan doesn't specify which of an element's 3 food items gets consumed when a player owns
  more than one kind; `FeedDragonRules` picks deterministically (first-in-`FoodConfig`-order that's
  owned) to keep the pure layer deterministic and its spec exact.

**Do next:**
1. Reconnect Studio to the now-running `rojo serve` (human action: click "Connect", or confirm
   it's already synced) and live-verify `FeedDragonTransaction` in Play mode — inject a test Baby
   dragon + matching food into a live profile via `execute_luau`, invoke the `Transaction` remote
   with `TransactionType.FeedDragon`, confirm `GrowthStage`/`FeedCount` advance and the food is
   consumed, confirm the 4th feed transforms to Adult, confirm wrong/no food rejects `MissingFood`
   cleanly with no console errors.
2. Phase B of `docs/prd/core-game-loop.md`: temporary Nursery/Baby-Area, spawn a Baby Dragon model
   (clone `ReplicatedStorage.DragonModels.Baby`) per hatched dragon, attach a Feed
   `ProximityPrompt` that sends only `DragonUID`. This is what actually lets a player reach
   `FeedDragonTransaction` in-game — right now it's remote-callable but has no world presence.
   `ReplicatedStorage.DragonModels.{Baby,Adult}` and `NestModels.Default` are ready to clone from.
3. Backlog item 3 (engine-lane activation ADR) remains open/unblocked if the human wants to switch
   lanes instead.

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions/machine restarts — **verify with `tasklist`/`curl localhost:34872` before
assuming it's up**, don't just trust a prior session's note that it "keeps running." Bash tool
needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"` prefixed before `ci/*.sh` calls in this
environment. The Studio MCP's `execute_luau` on the `Server` datamodel does NOT reliably share
Luau's `require()` module cache with the live running game — don't trust ad-hoc server-side state
dumps via MCP for anything beyond read-only sanity checks; verify behavior through the actual
remote/UI surface instead.
