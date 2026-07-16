# Backlog

> Always load. Ordered by priority — pick the top item unless told otherwise. Numbering is stable;
> `AGENTS.md`'s gated-actions section and `ci/run-tests.sh` already reference item **#3** by number
> (engine-lane activation) — don't renumber without updating those references too.

1. ~~**Profile schema, validation, and session lock**~~ — **DONE 2026-07-14**
   DoD met: `src/shared/Domain/ProfileSchema.spec.luau` proves validation rejects malformed/missing
   fields; `src/shared/Domain/SessionLock.spec.luau` proves a same-server reclaim succeeds, a
   different server is blocked while the lock is fresh, and it can claim once the lock expires.
   `ci/run-tests.sh fast` → real `PASSED` (4 specs). Session lock enforcement itself is wired into
   `src/server/Persistence/DataService.luau` (engine glue, not Lune-testable — see
   `memory-bank/progress.md` for what's verified there vs. what still needs a manual Studio pass).

2. ~~**Buy Egg transaction**~~ — **DONE 2026-07-15**
   DoD met: `src/shared/Domain/BuyEggRules.spec.luau` proves Gold deduction and egg grant commit
   atomically (never one without the other), and proves insufficient-gold/malformed-payload/
   disabled-tier/over-cap requests are all rejected without touching the profile.
   Duplicate-request-ID protection is `PlayerRuntimeStore`'s `RequestCache` (runtime-only, per
   AGENTS.md §3.7) — live-verified in Studio (resending the same RequestId returned the identical
   cached result without a second charge); this dedupe layer isn't itself Lune-testable since it's
   keyed to a live `TransactionService.Submit` call, but `RequestCache.spec.luau` proves its
   eviction/lookup mechanics in isolation. `ci/run-tests.sh fast` → `PASSED` (12 specs). Also
   built, as reusable infrastructure for every future transaction: `TransactionType`/
   `TransactionCode`/`PayloadValidator`/`RateLimiter` (all pure + spec'd),
   `PlayerRuntimeStore`/`TransactionQueue`/`TransactionService` (engine glue, live-verified in
   Studio via MCP — see `memory-bank/progress.md` for the concurrency bug this surfaced and fixed).
   See `memory-bank/handoff.md`'s 2026-07-15 entry for where this deliberately deviated from the
   user-supplied plan doc (no profile schema change; `Rarity` string reused instead of a new
   numeric `EggTypeId`).

3. **Engine-lane activation ADR**
   DoD: an ADR under `adr/` that states the trigger/scope for turning on `ci/run-tests.sh engine`
   and Studio-based verification, approved by the human. Until this lands, the engine lane stays
   `NO_TESTS` by design (see `ci/run-tests.sh`).

4. ~~**Start Hatch and Claim Hatch transactions**~~ — **DONE 2026-07-16**
   DoD met: `src/shared/Domain/StartHatchRules.spec.luau` + `ClaimHatchRules.spec.luau` prove
   `FinishAt` is derived from the injected server `now` (never client-supplied), Claim grants
   exactly one dragon and consumes the pending hatch in the same commit, and a second claim of an
   already-claimed `HatchId` fails `NoHatchInProgress` (no double-grant). `ci/run-tests.sh fast` →
   `PASSED` (12 specs). Scope grew beyond the original DoD per user request (see
   `adr/ADR-002-hatch-state-and-dragon-schema.md`): multiple concurrent hatches per player (not a
   single slot), a world-visible (all-clients) hatching-egg model with a live countdown
   (`src/server/Services/HatchSpawner.luau` + `src/client/Hatch/HatchCountdownController.luau`),
   and client-triggered/server-revalidated auto-claim (`src/client/Hatch/AutoClaimController.luau`).
   Live-verified in Studio via MCP: 3 concurrent hatches (2 Common + 1 Rare) tracked independently
   and auto-claimed correctly; a Legendary hatch claimed before `FinishAt` was rejected with
   `HatchNotReady` (code 32); the hatching egg is a genuine `Workspace` descendant (not
   `PlayerGui`-scoped); stopping and restarting Play mid-hatch left the pending hatch and its
   remaining time intact and respawned its egg. `hatchDurationSeconds` values in `EggConfig.json`
   are placeholders (Common=5s per explicit test request) pending real balancing. Dragon `Element`
   is not yet rolled (no probability weights exist in `DragonConfig.json`) — flagged as a follow-up,
   blocks backlog item 5 wherever it needs `Element`.

5. ~~**Feed Dragon and growth calculation**~~ — **DONE 2026-07-16** (Rules/Transaction +
   Phase B world-presence, both live-verified)
   DoD met: `src/shared/Domain/FeedDragonRules.spec.luau` proves a correct-element Feed consumes
   exactly one matching food item and advances exactly one GrowthStage (`Baby_0`→`Baby_1`→...),
   proves wrong-element/no-food is rejected (`MissingFood`) without consuming anything or advancing
   state, and proves the 4th Feed transforms to `Adult` exactly once (a 5th Feed attempt rejects
   `DragonAlreadyAdult`, FeedCount never exceeds 4). `ci/run-tests.sh fast` → `PASSED` (14 specs);
   `ci/compile-check.sh` → `COMPILE_OK`; `ci/lint.sh` → `PASSED` (advisory). See
   `adr/ADR-003-feed-dragon-schema.md` for the schema this needed (`DragonRecord.Element`/
   `GrowthStage`/`FeedCount`, Element now rolled at hatch, Food reuses the existing generic
   `Profile.inventory` rather than a new bucket) and `docs/prd/core-game-loop.md` for the source
   plan. `FeedDragonTransaction` is wired into `TransactionService` (`TransactionType.FeedDragon`)
   the same way as every prior transaction.
   **Live-verified in Studio Play mode via the Roblox Studio MCP, 2026-07-16** (real client
   `Transaction:InvokeServer` calls, real player, real profile — not a mocked path): a full
   Buy→Hatch→(auto-)Claim→Feed×4 chain on a freshly-hatched Common/Earth dragon consumed exactly
   one `Mushroom` per Feed (10→6), advanced `Baby_0→Baby_1→Baby_2→Baby_3→Adult` one stage per call,
   the 4th Feed returned `BecameAdult=true` exactly once, a 5th Feed attempt rejected
   `DragonAlreadyAdult` (code 41), an unknown `DragonUID` rejected `DragonNotFound` (code 40), and a
   malformed payload rejected `InvalidRequest` (code 1). Also incidentally confirmed the
   backward-compat default from ADR-003 works live: ~20 pre-existing dragons hatched before this
   session all show `Element="Fire"` (the additive default), not an error. No console errors from
   game code (two benign `Rojo-Warn` HTTP-polling messages, unrelated to game logic). Added a
   permanent `AddTestFood` test-harness remote (`src/server/Remotes/RemotesSetup.luau` +
   `init.server.luau`, mirrors the existing `AddTestGold` pattern) since there was no way to grant
   Food for manual testing otherwise — Buy Food isn't a designed transaction yet.
   **Phase B (world-presence) DONE 2026-07-16:** new `src/server/Services/DragonSpawner.luau`
   (mirrors `HatchSpawner`'s pattern) spawns a clone of `ReplicatedStorage.DragonModels.Baby` per
   non-Adult owned dragon in a shared `Workspace.Nursery.<userId>` area (placeholder MVP location,
   one "lane" per player), each tagged `BabyDragon` with a `FeedPrompt` `ProximityPrompt` and a
   `FeedStatus` billboard showing `Fed X/4`. New `src/client/Dragon/FeedPromptController.luau` wires
   the prompt's `Triggered` to `FeedDragonTransaction` sending only `DragonUID` (per the plan doc),
   and shows `Need Food` on the prompt when the player owns none of the dragon's Element's food
   items (read-only presentational use of the existing `ProfileUpdated` snapshot). Wired into
   `init.server.luau`: respawns all Baby models on character load (rejoin-safe, same as
   `HatchSpawner.RespawnAllPending`), despawns on leave, spawns a new Baby model after a successful
   `ClaimHatch`, and after a successful `FeedDragon` either updates the `FeedStatus` label
   (`DragonSpawner.UpdateFeedCount`) or despawns the model entirely on `BecameAdult=true` (Adults
   get no world presence until Farm Assignment, backlog item 6, per the plan doc's Recommended MVP
   rule). `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh fast` → `PASSED` (14 specs,
   unchanged — this is engine-glue, no new pure Domain logic), `ci/lint.sh` → `PASSED`.
   **Live-verified in Studio Play mode via the Roblox Studio MCP, 2026-07-16:** `RespawnAllBaby`
   correctly recreated ~29 pre-existing Baby models on character load; a freshly-hatched dragon
   (`DragonUID=58`, `Element=Water`) got a `FeedPrompt` (`ActionText="Feed"`, `ObjectText="Water
   Dragon"`) and a `Fed 0/4` label at spawn; feeding it 4x via the real `Transaction` remote
   advanced `Baby_0→Baby_1→Baby_2→Baby_3→Adult` and the model was confirmed **despawned** from the
   Nursery exactly on the 4th (`BecameAdult=true`) feed, a 5th feed attempt on the same UID
   correctly rejected `DragonAlreadyAdult` (41); feeding a second, pre-existing dragon
   (`DragonUID=52`) once left it in the Nursery with its `FeedStatus` label live-updated to `Fed
   1/4` and its `FeedCount` attribute updated to `1` (no despawn, as expected below Adult). No
   console errors from game code.

6. **Assign Producer and Collect Nest transactions**
   DoD: spec proves only Adult dragons can be assigned to produce; spec proves Collect advances the
   production cycle and grants output atomically.

7. **Sell Production Egg transaction**
   DoD: spec proves inventory removal and Gold grant commit atomically; spec proves the Egg Variant
   multiplier (GDD §4.2) is applied server-side and never trusted from the client.

8. **Display assignment and one simple synergy bonus**
   DoD: spec proves a 2-same-element synergy bonus (GDD §3.4) applies only while both dragons stay
   displayed, and that the bonus is recalculated (derived), never persisted as a stored number.

9. **Save recovery, duplicate-request, and disconnect tests**
   DoD: spec proves a disconnect mid-transaction leaves the profile at either the pre- or post-commit
   snapshot, never a partial state; a duplicate-request-ID spec exists for every transaction above.

Backlog seeded 2026-07-14 from `README.md`'s "Recommended first MVP slices" (items 1-2 and 4-9 map
1:1 to README's list 1-8; item 3 is new, inserted to match the `(backlog #3)` references already
written into `AGENTS.md`).
