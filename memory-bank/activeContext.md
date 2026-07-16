# Active Context

> Always load. Current focus, last 3 done, current + next task. Overwrite this each `end-session`.

## Current focus

Backlog items 1, 2, and 4 are done. Item 5 (Feed Dragon)'s pure Rules/Transaction layer is done
this session (green specs, wired into `TransactionService`) but **not yet live-verified in Studio**
and has **no world-presence** yet (no Nursery, no Baby Dragon spawn, no Feed `ProximityPrompt`) —
so a player cannot actually trigger it in-game yet, only via a direct `Transaction` remote call.
MVP placeholder 3D assets for Dragon (Baby/Adult, same source mesh scaled two ways) and Nest are
already staged in `ReplicatedStorage.DragonModels`/`NestModels` (Studio-side, not git-tracked — see
`memory-bank/systemPatterns.md`), ready for whoever builds Phase B to clone from.

**Everything for this backlog item is driven by the user-supplied plan doc, saved verbatim at
`docs/prd/core-game-loop.md`** — read that first for the full state machine / schema / phase
breakdown before continuing items 5 (Phase B/C remainder), 6, or 7.

## Last 3 done (this session, 2026-07-16)

1. Sourced and vetted free Creator Store assets for the core loop's MVP models via the Roblox
   Studio MCP (`search_asset`/`insert_asset`/`inspect_instance`): rejected several candidates that
   had embedded combat/AI `Script`s or degenerate geometry (see `memory-bank/systemPatterns.md`'s
   "World-model asset locations" section for exactly which were rejected and why — this repeats
   the `CoreSkyboxSystem` lesson from ADR-002, never trust an imported model's scripts unread).
   Kept: one dragon mesh (asset `17597495724`) cloned twice via `Model:ScaleTo()` into
   `ReplicatedStorage.DragonModels.Baby`/`.Adult`, and a nest mesh (asset `488637788`) into
   `ReplicatedStorage.NestModels.Default`. Both confirmed script-free.
2. Wrote `adr/ADR-003-feed-dragon-schema.md` and implemented the Feed Dragon Rules/Transaction
   vertical slice: `Types.DragonRecord` gains `Element`/`GrowthStage`/`FeedCount`;
   `DragonConfig.json` gains a placeholder equal-weight `elementOdds` (Element was previously
   unrolled — flagged as a blocker in ADR-002); `WeightedRoll.pick` was generalized from
   Rarity-only to take an explicit ordered key list (new `Elements.luau` mirrors `Rarities.luau`);
   `ClaimHatchRules.luau` now also rolls `Element` and initializes `GrowthStage="Baby_0"`,
   `FeedCount=0`; new `src/shared/Domain/FeedDragonRules.luau` (+ spec) is the actual Feed
   Validate/Stage/Commit math; `FeedDragonTransaction.luau` is the thin handler, registered in
   `init.server.luau` under the already-reserved `TransactionType.FeedDragon`. `ProfileSchema.luau`
   validates the new fields with the same additive-default pattern as `pendingHatches.Position`.
3. All three CI gates green: `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh fast` →
   `PASSED` (14 specs, up from 12), `ci/lint.sh` → `PASSED` (ran `stylua src` once to clean a few
   pre-existing + new formatting diffs). Found `rojo serve` was **not running** this session (no
   process listening on the default port; Studio showed a stale "synced 1 day ago, connect?"
   prompt) — restarted it in the background, but did not click "Connect" in the user's live Studio
   session (a UI action on their shared session), so live Play-mode verification of
   `FeedDragonTransaction` is still outstanding.

## Current task

Memory write-back for this session (this update).

## Next task

Reconnect Studio to the now-running `rojo serve` (user needs to click "Connect", or re-run
`rojo serve` themselves) and live-verify `FeedDragonTransaction` in Play mode the same way every
prior transaction was verified (direct dragon/food injected into a test profile via `execute_luau`,
then invoke the `Transaction` remote and check the result code + profile deltas). After that, the
real remaining item-5 work is Phase B (`docs/prd/core-game-loop.md`): a temporary Nursery area,
spawning a Baby Dragon model (clone from `ReplicatedStorage.DragonModels.Baby`) per hatched dragon,
and a Feed `ProximityPrompt` that sends only `DragonUID` to the server. Alternatively, backlog item
3 (engine-lane activation ADR) is still open and unblocked if the human wants to switch lanes.
