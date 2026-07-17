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

   **Update 2026-07-17 (much later, per direct user spec): Feed prompt now hides itself when the
   player has no matching Food**, instead of staying clickable with a relabeled "Need Food"
   `ActionText` (the previous behavior let a player trigger a doomed Feed attempt anyway).
   `src/client/Dragon/FeedPromptController.luau`: when `isFoodOwned` is false, the
   `ProximityPrompt` is now `Enabled = false` (no button at all, can't be triggered) and a
   separate, purely client-side `BillboardGui` reads `"Need {Element} Food\n(Visit the Food
   Shop)"` in its place — e.g. `"Need Dark Food"`, matching the user's own "Need Fire Food"
   example. This hint is built lazily by the client (not `DragonSpawner`), since it's a
   presentational read of the local player's own inventory, not server-authoritative world
   state. No transaction/schema change — `FeedDragonTransaction`'s contract is untouched; an
   Adult already got no `FeedPrompt` at all (unchanged). `ci/compile-check.sh` → `COMPILE_OK`,
   `ci/run-tests.sh fast` → `PASSED` (24 specs, unchanged — client-only), `ci/lint.sh` →
   `PASSED`. **Live-verified in Studio:** zeroing a Baby's Element food server-side and pushing
   a snapshot flipped its `ProximityPrompt.Enabled` to `false` and showed the hint text exactly
   as designed; restoring the food flipped it back to `Enabled = true` / `ActionText = "Feed"`
   and hid the hint. No console errors.

6. ~~**Assign Producer and Collect Nest transactions**~~ — **DONE 2026-07-17** (Rules/Transaction
   layer, live-verified; world-presence not yet built)
   DoD met: `src/shared/Domain/AssignProducerRules.spec.luau` proves only an owned Adult, unassigned
   dragon can be assigned to an empty slot (rejects `DragonNotAdult`/`DragonAlreadyAssigned`/
   `SlotOccupied`/`SlotNotFound`); `src/shared/Domain/CollectNestRules.spec.luau` +
   `ProductionRules.spec.luau` prove Collect advances the production cycle (timestamp-based,
   capacity-capped at 12, no banked excess cycles) and grants `ProductionEggInventory.Normal`
   atomically in one commit, rejecting an empty Nest (`NestEmpty`). New schema approved via
   `adr/ADR-004-farm-slot-and-nest-schema.md` (`DragonRecord.AssignedSlotId`, `Profile.farmSlots`
   /`productionEggInventory`, `ProductionConfig.json`). `ci/compile-check.sh` → `COMPILE_OK`,
   `ci/run-tests.sh fast` → `PASSED` (17 specs), `ci/lint.sh` → `PASSED`. **Live-verified in Studio
   Play mode via the Roblox Studio MCP:** real `Transaction:InvokeServer` calls assigned a test
   Adult dragon to slot 1; re-assigning a different dragon to the same slot, re-assigning the same
   dragon elsewhere, assigning a Baby, and assigning to an unknown slot all returned the correct
   codes; `FastForwardProduction` (new test-only remote, mirrors `AddTestFood`'s pattern) rewound
   `ProductionStartedAt` by 630s (3.5 intervals) and Collect correctly granted exactly 3 eggs
   (floor, not 3.5); a second immediate Collect returned `NestEmpty`; rewinding by 9000s (50
   intervals) and collecting capped at exactly 12 eggs, not 50, confirming no excess-cycle banking;
   no console errors. **World-presence (spawning the Adult Dragon + Nest models, Assign/Collect
   `ProximityPrompt`s) is explicitly deferred to a follow-up pass** — same split as item 5's
   Rules/Transaction-then-Phase-B pattern; see `adr/ADR-004-farm-slot-and-nest-schema.md`'s
   Consequences section. Starting farm-slot count (3, all pre-unlocked) is an engineering
   placeholder, not GDD-sourced.
   **Update 2026-07-17 (later same day): the Nest/Collect half of this deferred world-presence is
   now done** — see item 7's update below (Assign's own walk-up-to-slot placement UI, GDD §9, is
   still not built; every farm slot so far only ever gets assigned automatically via ClaimHatch/
   FeedDragon's auto-placement, per ADR-005).

7. ~~**Sell Production Egg transaction**~~ — **DONE 2026-07-17** (Rules/Transaction layer;
   world-presence not yet built)
   DoD met: `src/shared/Domain/SellProductionEggRules.spec.luau` proves inventory removal and Gold
   grant commit atomically, the sell value is computed server-side as base variant value × the
   laying dragon's rarity `productionMultiplier` (verified against the GDD's own worked examples —
   a Common/Normal egg sells for 2 gold, a Mythic/Golden egg sells for the "jackpot" 1,000 gold),
   the same variant from two different-rarity dragons is valued independently rather than merged
   at one price, and an entirely empty inventory rejects `NothingToSell` rather than silently
   succeeding for 0 gold. Also resolved this item's two previously-open questions per new
   `adr/ADR-006-production-egg-rarity-inventory.md`: `productionEggInventory` is now nested by the
   laying dragon's Rarity (was a flat bucket with no rarity attribution — a real schema change; no
   migration for pre-existing flat saves, per direct user request, since this project is
   pre-launch dev data not worth preserving — an old flat save just reads back as empty), and
   `CollectNestRules` now
   rolls each produced egg's variant against the laying dragon's own rarity odds
   (`ProductionConfig.variantOddsByRarity`, transcribed from GDD §2) instead of always granting
   `Normal`. `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh fast` → `PASSED` (21 specs, up
   from 19 — two new spec files, `Variants.spec.luau` and `SellProductionEggRules.spec.luau`),
   `ci/lint.sh` → `PASSED`. **Live Studio pass attempted but inconclusive, not confirmed clean** —
   registered the real `SellProductionEgg`/updated `CollectNest` handlers and drove them via the
   actual `Transaction:InvokeServer` remote (not a direct Rules call): a real Collect on a Common
   dragon's slot and an Epic dragon's slot both returned `Success=true` with plausible per-call
   `VariantCounts` (e.g. the Epic slot's 9 eggs came back as a Normal/Golden/Giant/Heavy mix, not
   all-Normal). However, a follow-up profile read straight after showed the Epic dragon's bucket
   still at all-zero and `PlayerRuntimeStore.Get(player)` returning `nil`, which traces back to a
   manual `DataService.Load(userId, "diagnostic-job")` I ran mid-session to unblock an earlier
   `DataService.Get` returning `nil` — that call's own session-lock claim likely raced/interfered
   with the real `PlayerAdded` session, so this environment inconsistency is attributed to that
   diagnostic probe, not confirmed to be a defect in `CollectNestRules`/`SellProductionEggRules`
   themselves (both are still fully covered by the passing Lune spec suite, including the exact
   "different-rarity dragons' eggs land in separate buckets" case). Needs a clean live Studio/MCP
   pass next session (fresh Play, no manual `DataService` calls) to confirm a real Collect→Sell
   round-trip. World-presence (Nest egg-pile model, Collect `ProximityPrompt`, market-stall Sell
   prompt/UI) explicitly deferred to a follow-up, same split as items 5/6.
   **Update 2026-07-17 (later same day): world-presence now DONE**, per direct follow-up user
   request. New `src/server/Services/NestSpawner.luau` clones the already-staged
   `ReplicatedStorage.NestModels.Default` (a Creator Store "Bird's Nest" asset, see
   `memory-bank/systemPatterns.md`) once a Farm Slot's `ProductionStartedAt` is set (Feed's 4th
   commit, a manual `AssignProducer`, or on rejoin), plus a `PileAnchor` part holding up to 5
   placeholder egg-pile `Part`s (real per-variant models don't exist since a not-yet-collected
   egg's variant genuinely isn't rolled until Collect — a flagged simplification, not a bug) and a
   counter badge beyond 5 (GDD §5). A new 15s `task.spawn` loop in `init.server.luau` re-runs the
   same `ProductionRules.Advance` Collect already uses (bookkeeping-only, grants nothing) so the
   pile visibly grows between Collects instead of only updating right after a transaction. New
   `src/server/Services/MarketStallSpawner.luau` builds one placeholder table+awning stall per
   player (`FarmPlotSpawner.StallPosition`, a new fixed-offset placeholder, same caveat as
   `PLOT_ORIGIN`/`NURSERY_ORIGIN` about Plot Expansion/item 13 growing past it). New
   `src/client/Production/CollectPromptController.luau`/`SellPromptController.luau` mirror
   `FeedPromptController`'s Trigger→`Transaction:InvokeServer` pattern exactly (`CollectNest`
   sends `SlotId`; `SellProductionEgg` sends an empty payload per GDD §8's "Sell all only"), with
   a transient BillboardGui showing `+N eggs`/`+N gold` on success. `ci/compile-check.sh` →
   `COMPILE_OK`, `ci/run-tests.sh fast` → `PASSED` (21 specs, unchanged — engine-glue only),
   `ci/lint.sh` → `PASSED`. **Live-verified in Studio Play mode via the Roblox Studio MCP** (a
   clean pass, unlike this item's earlier attempt above): 3 real Nests spawned matching the 3
   already-Adult-assigned Farm Slots (Common/Epic/Rare dragons), each with a correctly-capped
   5-egg pile, a working counter badge (`x7`, `x12`), and `ActionText` correctly reading "Collect
   All" (count ≥ 2); a real `Transaction:InvokeServer` Collect on slot 1 (7 eggs) returned
   `Success=true`, and the Nest immediately updated to an empty pile, disabled badge, and a
   disabled prompt; a real Sell via the Market Stall's exact `{}` payload returned an itemized
   `SoldLineItems` breakdown across `Common`/`Epic` × 4 variants (e.g. `Epic/Golden x3 @80=240`)
   summing to the correct `TotalGold`. No console errors. Not built: GDD §9's slot-picker/Assign
   walk-up UI (a separate, larger feature — still only auto-placement exists), and a rich itemized
   Sell-screen UI (GDD §8 describes one; this pass's Sell prompt fires directly like Feed/Collect,
   no confirmation screen, consistent with this codebase's established MVP-first prompt pattern).

8. **Display assignment and one simple synergy bonus**
   DoD: spec proves a 2-same-element synergy bonus applies only while both dragons stay displayed,
   and that the bonus is recalculated (derived), never persisted as a stored number. **Updated
   2026-07-17** per `docs/GROW_A_DRAGONA_IMPLEMENTATION_GDD.md` §9: the full table is now known
   (2/3/4/6/12 same-element dragons → +10%/+25%/+50%/+100%/+200%, Dark is the same curve but negative
   as a raid-slow effect instead of a gold/speed/quality/luck bonus) and only Adult dragons count
   toward it. Per `AGENTS.md`'s MVP scope ("simple derived synergy"), this item's DoD still only
   requires the 2-dragon tier to ship; the fuller 3/4/6/12 curve is a natural extension of the same
   derived-calculation function once 2 is proven, not a separate schema change.

9. **Save recovery, duplicate-request, and disconnect tests**
   DoD: spec proves a disconnect mid-transaction leaves the profile at either the pre- or post-commit
   snapshot, never a partial state; a duplicate-request-ID spec exists for every transaction above.

10. ~~**Food Shop (Buy Food transaction)**~~ — **DONE 2026-07-17** (ad-hoc user request, not part
    of the original README/GDD-derived list; not previously planned anywhere — `docs/prd/
    core-game-loop.md` explicitly only called for "a temporary Food test source")
    DoD: a player can buy every Food item (all 5 elements) for Gold from a Food Shop UI; spec proves
    Gold deduction and inventory grant commit atomically, rejecting an unknown item or unaffordable
    purchase without touching the profile.
    `src/shared/Domain/BuyFoodRules.spec.luau` proves this (18 specs total now). New
    `src/shared/Data/FoodShopConfig.json` (flat `{itemId: goldPrice}`, all 15 items priced at a flat
    `10` gold placeholder — no GDD/PRD source specifies Food prices at all, confirmed by re-reading
    the GDD). No schema/ADR needed: Food already reuses the generic `Profile.inventory` bucket
    (ADR-003), so this only added a price catalog + `TransactionType.BuyFood = 11` +
    `TransactionCode.InvalidFoodType = 13`. `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh
    fast` → `PASSED` (18 specs), `ci/lint.sh` → `PASSED`. **Live-verified in Studio Play mode via
    the Roblox Studio MCP:** real `Transaction:InvokeServer` calls for a successful buy, a
    stacking re-buy, an unknown item (`InvalidFoodType`), and a negative amount (`InvalidAmount`)
    all returned the correct codes/data; **also click-tested the actual `FoodShopUI`** (new
    `src/client/Shop/FoodShopUI.luau`, grouped by Element in a `ScrollingFrame`, mirrors
    `EggShopUI.luau`) via simulated mouse input — opened the shop, clicked "Buy" on Fish, confirmed
    Gold went `208,390 → 208,380` and the status line read "Bought 1 Fish for 10 gold." live in the
    UI, not just via direct remote calls. No console errors.

11. ~~**Adult Dragon world-presence + Inventory Baby/Adult breakdown**~~ — **DONE 2026-07-17**
    (ad-hoc user request; **overrides item 5's "Adults get no world presence until Farm
    Assignment" rule**, which itself was taken from `docs/prd/core-game-loop.md`'s Recommended MVP
    rule — the plan doc is left as-is/unedited since it's a saved verbatim historical record, but
    the actual game behavior deliberately now deviates from it)
    DoD: transforming a Baby to Adult (4th Feed) shows the Adult Dragon model in the Nursery in
    place of the Baby, instead of despawning with nothing; the Inventory panel's Dragon count line
    breaks each Rarity down by Baby vs. Adult stage, for easier MVP debugging.
    `src/server/Services/DragonSpawner.luau`: `Spawn` now branches on `dragon.GrowthStage`, cloning
    `ReplicatedStorage.DragonModels.Adult` (already staged in Studio, confirmed live via the Studio
    MCP — no new asset work needed) instead of `.Baby` for an Adult, tagging it `AdultDragon`
    (distinct from `BabyDragon`) with no `ProximityPrompt` (nothing to feed) and a
    `"{Element} Dragon (Adult)"` billboard instead of `Fed X/4`. `FeedPromptController` needed no
    change — it only ever attaches to the `BabyDragon` tag, so it correctly never sees Adult
    models. `RespawnAllBaby` renamed to `RespawnAll` and its filter changed from
    `GrowthStage ~= "Adult"` to `AssignedSlotId == nil`, so both Baby and not-yet-assigned Adult
    dragons reappear in the Nursery on rejoin (a dragon already assigned to a Farm Slot still gets
    no Nursery model — its world presence belongs at the Farm Slot, item 6's still-unbuilt
    follow-up). `init.server.luau`'s `FeedDragon` post-commit handler now re-`Spawn`s after
    `Despawn` on `BecameAdult=true` instead of despawning only. `src/client/Inventory/
    EggInventoryUI.luau`'s dragon-count line now groups by `` `{Rarity} {Baby|Adult}` `` (e.g.
    `Common Baby x5, Common Adult x10`) instead of by Rarity alone. No schema/ADR change — purely
    Runtime-only world-presence + client display, no new persistent fields. `ci/compile-check.sh`
    → `COMPILE_OK`, `ci/run-tests.sh fast` → `PASSED` (18 specs, unchanged — engine-glue/UI only,
    no new pure Domain logic), `ci/lint.sh` → `PASSED`. **Live-verified in Studio Play mode via the
    Roblox Studio MCP:** fed an existing `Baby_2` dragon (UID `5`) twice via the real `Transaction`
    remote to reach Adult; confirmed via `inspect_instance` the Nursery model was tagged
    `AdultDragon` (not `BabyDragon`), had no `ProximityPrompt` child, and its billboard read "Fire
    Dragon (Adult)"; screenshot-confirmed multiple Adult models visibly standing in the Nursery
    alongside Baby models. Opened the real Inventory UI and screenshot-confirmed the Dragons line
    read `Common Baby x5, Common Adult x10, Rare Adult x4, Epic Baby x1, Epic Adult x2, Legendary
    Baby x2, Legendary Adult x4, Mythic Baby x2, Mythic Adult x1`. No console errors. User
    mentioned a future evolution animation as a "later" idea, explicitly not part of this pass —
    not implemented, no animation was added.

    **Update 2026-07-17 (later same day):** the Baby/Adult bucket above was upgraded to full detail
    (Rarity + Element + exact `GrowthStage`) per direct follow-up user request ("cần đầy đủ để dễ
    debug"). `DragonSpawner`'s billboard text is now e.g. `"Rare Fire - Baby_1 (Fed 1/4)"` or
    `"Mythic Earth - Adult"` (added `Rarity`/`GrowthStage` `SetAttribute`s alongside the existing
    `Element`; the Feed `ProximityPrompt`'s `ObjectText` also gained `Rarity`).
    `EggInventoryUI.luau`'s dragon line now groups by `` `{Rarity} {Element} {GrowthStage}` ``
    (e.g. `Common Fire Adult x1, Rare Fire Baby_1 x1`) instead of the coarser Baby/Adult bucket;
    `inventoryFrame`/`dragonsLabel` were made taller to fit more lines. `ci/compile-check.sh` →
    `COMPILE_OK`, `ci/run-tests.sh fast` → `PASSED` (18 specs), `ci/lint.sh` → `PASSED`.
    **Live-verified in Studio:** hatched a fresh Rare Fire dragon, fed it once, confirmed via
    `execute_luau` that its world billboard read exactly `"Rare Fire - Baby_1 (Fed 1/4)"` and two
    pre-existing Adults read `"Mythic Earth - Adult"`/`"Rare Water - Adult"`; screenshot-confirmed
    the Inventory UI's Dragons line showed the same full-detail breakdown. No console errors.

12. ~~**ClearTestDragons debug harness**~~ — **DONE 2026-07-17** (ad-hoc tooling request, not a
    player-facing feature)
    User asked to clear all of the test player's dragons to restart testing from a clean slate.
    Added `ClearTestDragons` (`RemotesSetup.luau` + `init.server.luau`), same pattern as
    `AddTestGold`/`AddTestFood`/`AddTestDragon`/`FastForwardProduction`: sets `profile.dragons = {}`,
    resets every `profile.farmSlots` entry to empty (no dangling `AssignedDragonUID` pointing at a
    deleted dragon), and calls `DragonSpawner.DespawnAll` to clear the Nursery. Never touches gold/
    inventory/eggs. Fixed one `selene` unused-variable warning in the reset loop.
    `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh fast` → `PASSED` (18 specs), `ci/lint.sh`
    → `PASSED`. **Live-verified in Studio:** granted a test dragon, fired `ClearTestDragons`,
    confirmed dragon count dropped to 0, Nursery folder had 0 children, and assigning the
    now-deleted dragon UID correctly returned `DragonNotFound` (no dangling references). No console
    errors.

    **Update 2026-07-17 (later same day):** added a client-side "Clear Dragons" button
    (`src/client/init.client.luau`, order `3` in the existing `makeButton` test-harness row
    alongside `+10 Gold`/`-10 Gold`/`+10000 Gold`) that fires `ClearTestDragons` directly, per
    direct follow-up user request — previously it could only be fired via `execute_luau`.
    Live-verified: granted 4 test dragons, screenshotted the Nursery showing all 4 world models,
    clicked the real "Clear Dragons" button via simulated mouse input, screenshotted again
    confirming all 4 models vanished instantly, and confirmed via `execute_luau` the profile's
    dragon count dropped to 0. No console errors.

13. **Plot Expansion transaction** *(new 2026-07-17 — added because
    `docs/GROW_A_DRAGONA_IMPLEMENTATION_GDD.md` §6 defines it with concrete, real numbers that
    didn't exist anywhere before; not in the original README/GDD-derived seed list)*
    DoD: spec proves a player can spend Gold to raise farm-slot capacity one level at a time
    (2→4→6→8→10→12 slots at 500/2,000/8,000/25,000/80,000 gold), rejecting insufficient-gold and
    already-at-max-level requests without touching the profile; the new slot count is derived from
    a stored `plotLevel` (or equivalent), never trusted from the client. Needs its own schema pass
    (a new `Profile` field for plot level, since `farmSlots` is currently sized once at profile
    creation from the static `ProductionConfig.startingFarmSlots` and never grown) — likely needs an
    ADR per `AGENTS.md`'s gated-actions rule for save-schema changes. **Note (2026-07-17):** when
    this ships, it must also rebuild `FarmPlotSpawner`'s fence/ground (see item 14) — that module
    currently only sizes them once, at first `EnsurePlot` call, from whatever slot count exists then.

14. ~~**Farm Plot world-presence, auto Farm-Slot placement, and free starter Hatching Egg**~~ —
    **DONE 2026-07-17** (direct user request to wire up the full GDD Section 1 first-join flow and
    "chưa setup farm plot nữa" — the plot itself still didn't physically exist)
    DoD: a physical fenced Farm Plot with one ground tile per Farm Slot exists per player; a
    freshly-hatched Baby is auto-placed on the first open slot (no manual AssignProducer call
    needed for its first placement) and production auto-starts the instant it becomes Adult; a
    brand-new profile gets one free Hatching Egg, rolled at real Common-tier odds, sitting on the
    plot from the first join.
    New `adr/ADR-005-farm-plot-and-starter-hatch.md` (approved changes to already-shipped
    `ClaimHatchRules`/`FeedDragonRules`/`ProfileSchema`, since `AssignProducerRules`'s Adult-only
    gate stays untouched — see that ADR for why auto-placement doesn't go through
    `AssignProducerTransaction`). `ClaimHatchRules.spec.luau`/`FeedDragonRules.spec.luau` grew 3
    cases each; new `StarterHatchRules.luau` + `.spec.luau` (4 cases); `ProfileSchema.spec.luau`
    grew 3 cases for `starterHatchGranted`'s asymmetric default. `ci/compile-check.sh` →
    `COMPILE_OK`, `ci/run-tests.sh fast` → `PASSED` (19 specs, up from 18 — one new spec file),
    `ci/lint.sh` → `PASSED`. New `src/server/Services/FarmPlotSpawner.luau` (primitive-Part
    placeholder fence + tiles, no Toolbox/Studio-authored asset exists for this yet);
    `DragonSpawner` now positions an assigned dragon on its Farm Plot tile and `RespawnAll` covers
    every owned dragon (previously only unassigned ones respawned into the Nursery — this closes
    ADR-004's deferred world-presence gap for the Adult-on-slot case, though the Nest egg-pile model
    itself still isn't built).
    **Not Studio-verified this pass** — no Roblox Studio MCP session was available; only
    `rojo serve default.project.json` was started (listening on `localhost:34872`) so the user's own
    Studio + Rojo plugin can connect. Needs a manual/MCP Studio pass next session to confirm the
    fence/tiles render sensibly, a fresh hatch visually lands on slot 1, and the starter egg appears
    and hatches correctly for a brand-new profile.

15. ~~**Hatch reveal cinematic (shake/crack/reveal/summary, rarity-scaled)**~~ — **DONE
    2026-07-17** (ad-hoc feature request with a mockup + two detailed follow-up spec messages,
    not part of the original README/GDD-derived list)
    DoD: every hatch plays the same universal 4-beat structure (shake → crack & flash → reveal →
    non-blocking summary) regardless of rarity; how dressed-up each beat gets escalates
    Common→Mythic (camera push-in/FOV, crack/reveal duration, hitch, roar, screen flash, sound
    layering, particle tier, haptic bucket) per `docs/prd/hatch-reveal-sequence.md` (the full
    spec, captured verbatim from chat). New `src/shared/Data/HatchVisualConfig.json` (the
    authored per-rarity numbers/colors/sound cues) + `src/shared/Domain/HatchVisualConfig.luau`
    (pure `ValidateEscalation` check) + `HatchVisualConfig.spec.luau` (6 cases, proving the real
    authored config escalates monotonically and rejecting numeric/boolean/haptic regressions).
    `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh fast` → `PASSED` (22 specs, up from
    21), `ci/lint.sh` → `PASSED`. No save-schema/transaction-contract change — reused
    `ClaimHatchTransaction`'s existing `DragonId`/`Rarity`/`AssignedSlotId` result and the
    already-shipped auto-placement (backlog item 14 / ADR-005); this is 100% Runtime-only
    presentation (AGENTS.md data classification), and per `docs/prd/core-game-loop.md` the reveal
    never determines RNG or player data.
    Engine glue: `src/client/Hatch/HatchRevealController.luau` now owns the whole ClaimHatch round
    trip (previously `AutoClaimController` fired-and-forgot the InvokeServer call) since the
    shake/crack beats must play *before* the claim and the reveal/summary beats need its result;
    `AutoClaimController` was trimmed to just noticing when a hatch is ready and delegating. New
    `src/client/Hatch/SummaryCardUI.luau` (Beat 4: fades ~2s or dismisses on any tap). Camera
    lock uses `CameraType.Scriptable` + `Humanoid.WalkSpeed/JumpPower/JumpHeight = 0` during the
    shot, restored the instant the reveal beat ends; concurrent hatches (a supported case per
    ClaimHatchRules) share one camera via a simple lock/queue rather than fighting over it.
    10 free Creator Store sound assets were sourced and inserted via the Roblox Studio MCP
    (`search_asset`/`insert_asset`) into `ReplicatedStorage.HatchSounds`, reused/layered across
    rarities via per-cue volume/pitch/delay rather than one unique clip per table cell — **flagged
    as [Unverified]**: matched by keyword search only, several (`MagicChime`, `MagicalSwell`,
    `RevealPop`/`SparkleTwinkle`, `ShimmerSweep`) are lower-confidence placeholders a real sound
    pass should audition. Haptics use `HapticService:SetMotor`, gated by `IsVibrationSupported` +
    `pcall`; **also unverified** — no physical device was attached to confirm real vibration,
    only that the calls don't error. "Light rays" and the Mythic screen flash are simplified
    (thin Neon parts / a flat rainbow `Frame` flash, not real Beams or a radial vignette).
    **Live-verified in Studio Play mode via the Roblox Studio MCP:** real `Transaction:InvokeServer`
    calls for both a Common hatch (dragon `88`, Common/Water) and a Mythic hatch (dragon `90`,
    Mythic/Fire — the tier exercising every optional code path: hitch, roar, screen flash,
    rainbow cascade, multi-layer delayed sound cues) completed with no console errors; camera
    (`CameraType`/`FieldOfView`) and `Humanoid.WalkSpeed` were confirmed back to their original
    values immediately after each reveal, and a mid-sequence screenshot showed the camera visibly
    pushed in tight on the Mythic egg. A pre-existing session quirk unrelated to this feature was
    hit and worked around: the test player's profile hadn't finished loading via the normal
    `PlayerAdded` path when Play mode started, so a manual `DataService.Load` call was needed
    before granting test gold — same class of environment issue flagged in item 7's notes, not a
    defect in this feature.

16. ~~**Storage: place/manage/swap dragons on Farm Slots**~~ — **DONE 2026-07-17** (ad-hoc
    feature request, full spec in `docs/prd/storage-and-farm-slot-management.md`)
    DoD: farm-full overflow already went to Storage (`AssignedSlotId = nil`, backlog item 14) —
    this item makes Storage actually usable: walking up to an empty slot offers "Place Dragon"
    (opens a Storage Picker grid, any GrowthStage selectable, closes on pick); walking up to an
    occupied slot offers "Manage Dragon" → Send to Storage or Swap Dragon (atomic, one commit,
    no dragon lost/duplicated); a HUD "Collection" button views every owned dragon grouped with
    a duplicate count, sortable by Rarity/newest, but never places one itself (per direct spec).
    `AssignProducerTransaction` (Adult-only, zero client callers ever) was renamed/generalized to
    `PlaceDragonRules`/`PlaceDragonTransaction` (`src/shared/Domain/PlaceDragonRules.spec.luau`,
    9 cases) rather than kept alongside a new overlapping transaction. New
    `SendToStorageRules`/`.spec.luau` (8 cases) and `SwapDragonRules`/`.spec.luau` (11 cases,
    including "neither dragon lost or duplicated" and every rejection code). New
    `TransactionCode.NestNotEmpty`/`NoDragonInSlot`: tracing `ProductionRules.Advance` showed a
    slot with `AssignedDragonUID = nil` but `UncollectedEggCount > 0` is a dead state no code
    recovers from (permanently uncollectable eggs), so Send-to-Storage/Swap hard-reject until the
    Nest is collected first — this is enforced server-side, not just client UX. No save-schema
    change and no `adr/` needed (Storage is exactly the pre-existing `AssignedSlotId == nil`
    state; only a previously-unused transaction's validation rule loosened).
    `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh fast` → `PASSED` (24 specs, up from
    22), `ci/lint.sh` → `PASSED`. New client modules: `src/client/Storage/StorageCardList.luau`
    (shared card-grid renderer), `StoragePickerUI.luau`, `ManageDragonMenu.luau`,
    `FarmSlotPromptController.luau` (wires the new "FarmSlot" tag/prompt, reads the prompt's own
    `ActionText` to pick Place vs Manage rather than a second attribute that could drift), and
    `CollectionViewerUI.luau`. `FarmPlotSpawner` tiles gained their first-ever `ProximityPrompt`
    (`FarmPlotSpawner.UpdateSlotPrompt`, mirroring `NestSpawner.UpdatePileCount`'s
    refresh-on-every-call pattern); `ClearTestDragons` was fixed to also reset tile prompts back
    to "Place Dragon" (previously only reset profile/world dragons, leaving stale "Manage Dragon"
    prompts after a clear). Caught and fixed before shipping: the old `AssignProducer` branch
    unconditionally called `NestSpawner.EnsureNest` (harmless when Adult-only), which would have
    incorrectly shown a Nest for a placed/swapped-in Baby now that any GrowthStage is allowed —
    all three post-commit handlers gate Nest presence on `GrowthStage == "Adult"`, despawning it
    otherwise.
    **Live-verified in Studio Play mode via the Roblox Studio MCP:** real `Transaction:
    InvokeServer` calls end-to-end for Place (Storage → empty slot), Send to Storage (slot →
    Storage, Nest despawned, prompt reverted to "Place Dragon"), and Swap (atomic — both
    dragons' world models and both tiles' prompts ended up in the exactly-correct state, `Old`
    dragon back in the Nursery, `New` dragon on the tile) — confirmed via `ClaimHatch`-created
    (not directly-mutated) dragons after direct-mutation test dragons hit a `DataService`-cache
    isolation quirk in this tool's `execute_luau` (mutations from separate `execute_luau` Server
    calls don't reliably share state with the live running server's cache — Workspace state and
    the real `Transaction` remote's own return payloads are reliable, and were used for every
    check instead). Also confirmed via real simulated mouse clicks (not direct API calls): the
    Storage Picker renders correct cards/sort/accent-colors, and the HUD Collection button opens
    a correctly-grouped, correctly-counted, on-farm-vs-Storage-labeled view (e.g. two
    directly-mutated Common Fire Adults correctly merged into one "x2 ... All in Storage" card).
    No console errors from game code.

    **Update 2026-07-17 (later same day): fixed a design-doc mismatch the user caught** — a
    Storage dragon still got a world model in the shared "Nursery" folder (a leftover fallback
    from before this item existed, when unassigned dragons had nowhere else to go). Re-reading
    `docs/GROW_A_DRAGONA_IMPLEMENTATION_GDD.md` Section 12 confirms: *"Storage isn't a physical
    building on the plot... there's nothing to walk up to."* `DragonSpawner.Spawn` now no-ops
    entirely for any dragon with `AssignedSlotId == nil` — only a Farm-Slot-assigned dragon gets
    a world model at all; a Storage dragon is visible only through the Storage Picker / HUD
    Collection button, never a physical location. This also deleted the now-dead "Nursery lane
    grid" position math (`NURSERY_ORIGIN`/`laneOrigin`/`slotPosition`/`playerLane`) since every
    remaining call to `FarmPlotSpawner.SlotPosition` is now guaranteed non-nil. No transaction/
    schema change — `SendToStorageTransaction`/`SwapDragonTransaction`'s existing
    Despawn-then-Spawn post-commit calls already handle this correctly for free (Spawn simply
    no-ops when the moved-out dragon's `AssignedSlotId` is now `nil`). `ci/compile-check.sh` →
    `COMPILE_OK`, `ci/run-tests.sh fast` → `PASSED` (24 specs, unchanged — engine-glue only),
    `ci/lint.sh` → `PASSED`. **Live-verified in Studio:** on a profile with 2 Farm-Slot dragons
    and 2 Storage dragons, the Nursery folder contained world models for exactly the 2
    Farm-Slot dragons and none for the 2 Storage ones. No console errors. Known minor gap this
    surfaces (not fixed, low priority): a hatch that overflows straight to Storage (farm full)
    now never gets a world model at all, so the hatch-reveal summary card's Element readback
    (`docs/prd/hatch-reveal-sequence.md`, which reads the newly-spawned model's `Element`
    attribute since `ClaimHatchTransaction`'s result doesn't carry it) falls back to "Unknown"
    for that specific case — previously a rare edge case, now the expected outcome whenever a
    hatch overflows to Storage.

Backlog seeded 2026-07-14 from `README.md`'s "Recommended first MVP slices" (items 1-2 and 4-9 map
1:1 to README's list 1-8; item 3 is new, inserted to match the `(backlog #3)` references already
written into `AGENTS.md`). Items 10-12 were added 2026-07-17, out of the original seeded sequence,
per direct user request. Item 13 was added 2026-07-17 after ingesting
`docs/GROW_A_DRAGONA_IMPLEMENTATION_GDD.md`, a more detailed successor to `Doc/Grow_a_Dragona_GDD.txt`
supplied by the user; that same pass also updated items 7-8's notes and promoted `elementOdds`/
`startingFarmSlots`/`FoodShopConfig` prices from engineering placeholders to real GDD-sourced values
(see `src/shared/Data/README.md`). Item 14 was added and completed the same day (2026-07-17), per
direct follow-up user request to wire up the GDD's Section 1 first-join flow and build the
still-missing physical Farm Plot.
