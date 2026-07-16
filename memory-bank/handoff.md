# Handoff

> Always load, read first. Last session's state transfer. Overwritten each `end-session`.

## Session: 2026-07-16 — Core-loop plan received; MVP assets sourced; Feed Dragon (backlog item 5) built and live-verified

**Verified state:** All three gates green: `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh
fast` → `PASSED` (14 specs, up from 12), `ci/lint.sh` → `PASSED`. **Live-verified in Studio Play
mode via the Roblox Studio MCP** (see step 8 below) — `rojo serve` was found not running early in
the session, restarted, the human reconnected Studio, and `FeedDragonTransaction` was then driven
through real client `Transaction:InvokeServer` calls end-to-end successfully.

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
   button via simulated input — that's a UI action on the user's own live/shared Studio session;
   asked the human to do it instead. Committed everything up to this point as `4b02518`.
8. Human reconnected Studio ("đã kết nối thành công") and asked to commit + reconnect (done in
   step 7/this commit). Confirmed the sync landed (`ReplicatedStorage.Shared.Domain.FeedDragonRules`
   etc. present via `search_game_tree`). **Found a real gap while trying to test:** there was no way
   to grant Food to a live profile for manual testing (no Buy Food transaction exists, and
   `AddTestFood` had been removed in an earlier cleanup session) — added it back
   (`src/server/Remotes/RemotesSetup.luau` + `init.server.luau`, same pattern as the still-present
   `AddTestGold`), granting a fixed amount of every food item across all 5 elements (payload-free,
   since a hatched dragon's `Element` is random and can't be known in advance by a manual tester).
   Also confirmed empirically that **`execute_luau` on the `Server` datamodel really cannot read
   live profile state** (`DataService.Get(userId)` returned `nil` for an actually-online player) —
   consistent with the pre-existing environment note below; worked around it by driving everything
   through real `Transaction:InvokeServer` calls from the **Client** datamodel instead (a genuinely
   real client, not a mock), and reading results back from the `TransactionResult.Data` each call
   already returns, plus one `ProfileUpdated` listener snapshot for a full-state check.
   **Live-verified, Play mode, real remote calls, no console errors from game code** (two benign
   `Rojo-Warn` HTTP-polling messages only): Buy Common egg → Start Hatch → auto-Claim (a fresh
   dragon, `Id=42`, rolled `Element=Earth`) → Feed ×4: `Baby_0→Baby_1→Baby_2→Baby_3→Adult`, one
   `Mushroom` consumed per Feed (10→6 exactly), `BecameAdult=true` only on the 4th call, a 5th Feed
   rejected `DragonAlreadyAdult` (41), an unknown `DragonUID` rejected `DragonNotFound` (40), a
   malformed payload rejected `InvalidRequest` (1). Incidentally also confirmed ADR-003's
   backward-compat default live: ~20 pre-existing dragons (hatched before this session) all show
   `Element="Fire"` — the additive default, not an error. **Backlog item 5 is now marked
   Rules/Transaction DONE + live-verified in `memory-bank/backlog.md`.** Re-ran all 3 CI gates green
   after adding `AddTestFood`, then committed (`ba0cf89`).
9. User asked for hatching to be instant, no wait time at all. Set every `EggConfig.json` tier's
   `hatchDurationSeconds` to `0` (was a 5s-1800s per-rarity placeholder ramp from ADR-002) — no
   code change needed, since `StartHatchRules`/`ClaimHatchRules` already compute
   `FinishAt = now + hatchDurationSeconds` and reject only `now < FinishAt`, so duration `0` makes
   a hatch claimable the instant it starts. Documented as an addendum to
   `adr/ADR-002-hatch-state-and-dragon-schema.md` (a tunable-value change, not a new schema/
   contract decision) and in `src/shared/Data/README.md`. **Live-verified in Studio Play mode:**
   Buy → Start Hatch → the pending hatch was already gone (`NoHatchInProgress` on a manual
   re-claim attempt) within about the round-trip time of one more MCP tool call — roughly a
   second of real latency, not the old 5s-30min wait. Hit one real sync gotcha along the way: a
   Play session snapshots the Edit-mode DataModel at the moment Play starts, so a file edit made
   right before pressing Play can race the sync — confirm the value read back correctly in Edit
   mode first, *then* start Play, rather than editing and immediately starting Play back-to-back.

**Deviations from the plan doc** (see `adr/ADR-003-feed-dragon-schema.md` for full reasoning):
- No `FoodInventory = {FireFood, WaterFood, ...}` bucket — reused the existing generic
  `Profile.inventory`, keyed by the concrete `FoodConfig.json` item names.
- `AssignedSlotId` not added to `DragonRecord` yet — that's backlog item 6's schema decision.
- The plan doesn't specify which of an element's 3 food items gets consumed when a player owns
  more than one kind; `FeedDragonRules` picks deterministically (first-in-`FoodConfig`-order that's
  owned) to keep the pure layer deterministic and its spec exact.

**Do next:**
1. Phase B of `docs/prd/core-game-loop.md`: temporary Nursery/Baby-Area, spawn a Baby Dragon model
   (clone `ReplicatedStorage.DragonModels.Baby`) per hatched dragon, attach a Feed
   `ProximityPrompt` that sends only `DragonUID`. This is what actually lets a player reach
   `FeedDragonTransaction` in-game — right now it's only remote-callable, no world presence yet.
   `ReplicatedStorage.DragonModels.{Baby,Adult}` and `NestModels.Default` are ready to clone from.
2. Backlog item 3 (engine-lane activation ADR) or item 6 (Assign Producer / Collect Nest) remain
   open/unblocked if the human wants to switch lanes instead. Item 6 needs its own ADR for Farm
   Slot/Nest schema — ADR-003 deliberately did not pre-approve it.

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions/machine restarts — **verify with `tasklist`/`curl localhost:34872` before
assuming it's up**, don't just trust a prior session's note that it "keeps running." Bash tool
needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"` prefixed before `ci/*.sh` calls in this
environment. The Studio MCP's `execute_luau` on the `Server` datamodel does NOT reliably share
Luau's `require()` module cache with the live running game — don't trust ad-hoc server-side state
dumps via MCP for anything beyond read-only sanity checks; verify behavior through the actual
remote/UI surface instead. **New this session:** after editing a data/script file, don't press Play
immediately — Rojo syncs into the **Edit-mode** DataModel, and starting Play snapshots whatever the
Edit-mode DataModel holds *at that moment*; if the sync hasn't landed yet, Play starts with stale
data and there's no error to signal it. Confirm the new value reads back correctly in `Edit`
datamodel via `execute_luau` first, *then* start Play — this cost one full extra Stop/Start cycle
this session when skipped.
