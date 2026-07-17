# Progress

> Always load. What works / what's left / known bugs. Only list something under "works" if a green
> `ci/run-tests.sh fast` proves it — this file must not get ahead of the tests.

## What works

Verified as of 2026-07-15 (toolchain installed via Rokit; all three gates run for real, not
smoke-tested):

- `ci/compile-check.sh` → real `COMPILE_OK` (`rojo build` + `luau-lsp analyze`, with real Roblox
  type definitions wired in — see `memory-bank/techContext.md`).
- `ci/run-tests.sh fast` → real `PASSED`, 12 specs (up from 4 on 2026-07-14), all pure Luau under
  `src/shared/Domain/`:
  - `Currency.luau` — safe `add`/`spend`: rejects negative/non-integer/NaN amounts, clamps `add` at
    a configured max, rejects `spend` beyond the current balance.
  - `Inventory.luau` — safe `add`/`remove`/`get`: rejects non-positive/non-integer quantities and
    empty item ids, clamps `add` at a configured max stack, deletes the key when a stack reaches 0,
    never mutates its input table.
  - `ProfileSchema.luau` — `default()`/`validate()`: builds a valid empty profile from a starting-
    gold value, accepts a well-formed raw profile, rejects non-table/negative-gold/malformed-
    inventory/missing-meta, defaults a missing session safely.
  - `SessionLock.luau` — `canClaim()`: same-server reclaim always succeeds, a different server is
    blocked while the lock is fresh, and can claim once the lock times out (boundary-tested).
  - **Added 2026-07-15 (backlog item 2, Buy Egg transaction):**
  - `PayloadValidator.luau` — `IsFiniteNumber`/`IsIntegerInRange`/`IsPositiveInteger`: rejects NaN,
    ±infinity, non-numbers, decimals-where-integer-required, and out-of-range values.
  - `RateLimiter.luau` — `tryConsume` sliding window: allows under the cap, rejects at the cap,
    prunes stale timestamps to free capacity, never mutates its input list.
  - `RequestCache.luau` — bounded requestId→result cache: `Get`/`Put`, evicts the oldest entry once
    over its max size.
  - `BuyEggRules.luau` — the actual Validate/Stage/Commit math: successful purchase deducts gold
    and grants eggs atomically; buying into an existing stack doesn't create a second one;
    insufficient gold rejects with gold/inventory untouched; malformed payloads (negative/zero/
    decimal/`math.huge`/NaN/over-max amount, unknown rarity, wrong type) are all rejected without
    touching the profile; a disabled tier and an over-`maxPurchaseAmount` request are both
    rejected; `Stage` itself never mutates the profile (only `Commit` does).
- **Added 2026-07-16 (backlog item 5, Feed Dragon — Rules/Transaction layer, live-verified; see
  `memory-bank/backlog.md` item 5 for what's still pending, i.e. Phase B world-presence):**
  `ci/run-tests.sh fast` → real `PASSED`, 14 specs (up from 12):
  - `Elements.luau` — fixed-order List/IsValid over the 5 elements, mirrors `Rarities.luau`.
  - `WeightedRoll.luau` — generalized from Rarity-only to `(orderedKeys, odds, rollValue)` so the
    same cumulative-bucket algorithm now also rolls Element; all existing call sites updated, no
    behavior change for Rarity rolling.
  - `ClaimHatchRules.luau` — a hatched dragon now also rolls an `Element` (independent
    `math.random()` from Rarity's) and starts `GrowthStage="Baby_0"`, `FeedCount=0`.
  - `FeedDragonRules.luau` — the actual Validate/Stage/Commit math: a correct-element Feed
    consumes exactly one owned matching food item (first match in `FoodConfig` order) and advances
    exactly one `GrowthStage`; wrong-element/no-food rejects `MissingFood` untouched; the 4th Feed
    transforms to `Adult` exactly once, a 5th rejects `DragonAlreadyAdult` (`FeedCount` never
    exceeds 4); unknown `DragonUID` rejects `DragonNotFound`; malformed payload rejects
    `InvalidRequest`; `Stage` never mutates the profile.
  - `ProfileSchema.luau` — `dragons` entries now validate/default `Element`/`GrowthStage`/
    `FeedCount` the same additive-field way as `pendingHatches.Position` (pre-feature saves default
    to Fire/Baby_0/0, not rejected).
  See `adr/ADR-003-feed-dragon-schema.md` for the full decision record (why Food reuses the
  generic `Profile.inventory` instead of a new bucket, why `AssignedSlotId` is deferred).
  **Live-verified in Studio Play mode via the Roblox Studio MCP, 2026-07-16**, real client
  `Transaction:InvokeServer` calls (not a mocked path): Buy→Hatch→auto-Claim→Feed×4 on a freshly-
  hatched Common/Earth dragon consumed exactly one `Mushroom` per Feed, advanced one `GrowthStage`
  per Feed, became `Adult` exactly on the 4th, and rejected `DragonAlreadyAdult`/`DragonNotFound`/
  `InvalidRequest` correctly; ~20 pre-existing dragons all showed the `Element="Fire"` backward-
  compat default, confirming that path works live too. Added `AddTestFood` (mirrors `AddTestGold`)
  to `RemotesSetup.luau`/`init.server.luau` as a permanent manual-test lever, since there was no
  other way to grant Food (no Buy Food transaction exists yet).
- **Added 2026-07-16 (backlog item 5, Phase B — Baby Dragon world-presence, engine-glue, no new
  pure Domain logic so `ci/run-tests.sh fast` stays at 14 specs):** new
  `src/server/Services/DragonSpawner.luau` (spawns/despawns/updates a clone of
  `ReplicatedStorage.DragonModels.Baby` per non-Adult owned dragon in a `Workspace.Nursery.<userId>`
  placeholder area, tagged `BabyDragon`, each with a `FeedPrompt` `ProximityPrompt` and a
  `FeedStatus` billboard showing `Fed X/4`) and `src/client/Dragon/FeedPromptController.luau`
  (wires the prompt's `Triggered` to `FeedDragonTransaction` sending only `DragonUID`; shows `Need
  Food` on the prompt when the player owns none of the dragon's Element's food, read-only off the
  existing `ProfileUpdated` snapshot). Wired into `init.server.luau`: respawn-all-Baby on character
  load, despawn-all on leave, spawn-on-ClaimHatch, update-or-despawn-on-FeedDragon.
  `ci/compile-check.sh` → `COMPILE_OK`, `ci/lint.sh` → `PASSED`.
  **Live-verified in Studio Play mode via the Roblox Studio MCP, 2026-07-16:** `RespawnAllBaby`
  correctly recreated ~29 pre-existing Baby models on character load; a freshly-hatched dragon
  (`DragonUID=58`, `Element=Water`) spawned with a working `FeedPrompt` and `Fed 0/4` label; 4 real
  Feed calls via the `Transaction` remote advanced it `Baby_0→Baby_1→Baby_2→Baby_3→Adult`, and the
  model was confirmed **despawned** from the Nursery exactly on the 4th (`BecameAdult=true`) feed —
  a 5th feed attempt correctly rejected `DragonAlreadyAdult`; a second, pre-existing dragon
  (`DragonUID=52`) fed once stayed in the Nursery with its `FeedStatus` label and `FeedCount`
  attribute live-updated to `Fed 1/4` (no despawn, correctly below Adult). No console errors from
  game code.
- `ci/lint.sh` → real `PASSED` (selene + stylua, both clean after adding `selene.toml` — see Known
  gaps — and running `stylua src` once).
- `rojo serve default.project.json` starts and listens; the client test harness (`src/client/`)
  connects via `ReplicatedStorage.Remotes` and renders Gold + inventory as plain text with 4
  `TextButton`s (+10 Gold / -10 Gold / +1 Fish / -1 Fish). **Click-tested for real in Studio Play
  mode, 2026-07-14 and 2026-07-15** (Studio MCP access): `Remotes` folder and `PlayerGui.TestHarness`
  render correctly; firing `AddTestGold`/`AddTestFood` round-trips through the services. **Golden
  path now proven (2026-07-15):** with the user's place having `Studio Access to API Services`
  enabled, Gold/Fish actually change and **persist across Stop → Start** — verified 3x, including
  firing a button and stopping immediately with no delay (see `DataService`/`init.server.luau` entry
  below for the bug this surfaced and fixed). The error path (DataStore unavailable) still renders
  `lastError` as on-screen text without crashing, for places without that setting enabled.
  **Added 2026-07-15:** "Buy 1 Common Egg" / "Buy 1 Rare Egg" / "Retry Last Request" buttons and a
  `TransactionLabel` calling the new `Transaction` `RemoteFunction`. Click/invoke-tested live in
  Studio Play mode via MCP (see the transaction framework entry below).
- `ci/gate-freshness.sh --stamp` recorded a real green signature after the above.

### Engine-glue layer (built, not unit-tested — by design, see AGENTS.md's deferred engine lane)

- `src/server/Persistence/DataService.luau` — `Load`/`Get`/`Save`/`Release`, in-memory profile
  cache keyed by `userId`, session lock enforced via the tested `SessionLock.canClaim`, DataStore
  calls wrapped in `pcall`. **Fixed 2026-07-14:** the initial `DataStoreService:GetDataStore(...)`
  call is now also `pcall`-wrapped — it used to throw unguarded and crash the entire server
  `require()` chain whenever DataStore was unavailable (e.g. unpublished Studio place), which silently
  prevented `RemotesSetup.Init()` from ever running. `Load`/`Save` now return
  `false, nil, "datastore unavailable: <reason>"` instead. **Known limitation (unchanged):** uses
  `SetAsync` (last-write-wins), not a compare-and-swap `UpdateAsync` — not hardened against true
  cross-server race conditions. That hardening is explicitly backlog item 9's job, not today's.
- `src/server/Services/CurrencyService.luau`, `InventoryService.luau` — thin wrappers binding the
  tested Domain functions to a player's live cached profile.
- `src/server/Remotes/RemotesSetup.luau` + `src/server/init.server.luau` — creates
  `ReplicatedStorage.Remotes` (5 `RemoteEvent`s), wires `Players.PlayerAdded`/`PlayerRemoving` to
  `DataService.Load`/`Release`, and wires each test button's remote to the matching Service call,
  pushing a `{gold, inventory, lastError}` snapshot back to that player after every action.
  **Fixed 2026-07-15:** found via live Studio testing that a button click followed by an immediate
  Stop could lose the change — `Release`'s `Save` call is a yielding `SetAsync`, and nothing held
  server shutdown open for it, while `Release`'s `(ok, err)` return was discarded (a failed save on
  disconnect was completely silent, no console output anywhere). Added `game:BindToClose(...)` to
  release/save every connected player before shutdown completes, and `warn(...)` on save failure on
  both the `PlayerRemoving` and `BindToClose` paths. Reverified 3x live: fire button → stop
  immediately → restart → value persisted correctly every time, no `warn()` output.
- `src/shared/Data/*.json` — `EggConfig`, `DragonConfig`, `FoodConfig`, `EconomyConfig`. See
  `src/shared/Data/README.md` for exactly which numbers are GDD facts vs. engineering placeholders.
  **Added 2026-07-15:** `enabled`/`maxPurchaseAmount` per hatching tier (engineering placeholders).
- **Added 2026-07-15 (backlog item 2) — Transaction framework:**
  `src/server/Runtime/PlayerRuntimeStore.luau` (per-player queue/rate-limit/dedupe-cache state,
  runtime-only, never persisted), `src/server/Transactions/Core/TransactionQueue.luau` (per-player
  FIFO serialization) and `TransactionService.luau` (dedupe → rate-limit → enqueue → Validate →
  Stage → Commit → cache-result orchestration), `src/server/Transactions/Economy/
  BuyEggTransaction.luau` (thin handler over `BuyEggRules`), and a `Transaction` `RemoteFunction`
  in `RemotesSetup.luau`. **Live-verified in Studio Play mode via MCP, 2026-07-15:** successful
  purchase with correct atomic Gold/egg deltas; resending the same RequestId returns the identical
  cached result without charging twice; invalid amount/rarity, insufficient-gold, and burst-traffic
  rate-limiting all return the expected `TransactionCode`; no console errors from game code.
  **Bug found and fixed live:** the first real invocation crashed the server thread with `cannot
  spawn non-suspended coroutine with arguments` — `TransactionQueue.Run` was kicking off
  `processNext` before its own `coroutine.yield()`, so the queued job tried to resume the caller's
  thread before it had actually suspended. Fixed by deferring the kick via `task.defer` instead of
  a direct/synchronous call; re-verified clean afterward. This class of bug is exactly why the
  engine-glue lane isn't Lune-tested (see AGENTS.md's deferred engine lane) — a live Studio pass
  caught something the fast lane structurally cannot.

- **Added 2026-07-17 (backlog item 6) — Assign Producer / Collect Nest transactions:**
  `src/shared/Domain/ProductionRules.luau` (pure timestamp→completed-cycles calc, capacity-capped,
  no excess-cycle banking), `AssignProducerRules.luau`, `CollectNestRules.luau` (all spec'd), thin
  handlers `src/server/Transactions/Production/AssignProducerTransaction.luau` +
  `CollectNestTransaction.luau`, new schema per `adr/ADR-004-farm-slot-and-nest-schema.md`
  (`DragonRecord.AssignedSlotId`, `Profile.farmSlots`/`productionEggInventory`,
  `ProductionConfig.json`: 180s interval / 12-egg capacity / 3 starting slots). **Live-verified in
  Studio Play mode via MCP, 2026-07-17:** real `Transaction:InvokeServer` calls for both
  transactions; all 5 rejection codes (`SlotOccupied`, `DragonAlreadyAssigned`, `DragonNotAdult`,
  `SlotNotFound`, `NestEmpty`) confirmed live; a new `FastForwardProduction` test-only remote
  rewound a slot's `ProductionStartedAt` to prove the floor-division cycle math (630s → exactly 3
  eggs, not 3.5) and the 12-egg capacity cap (9000s/50 intervals → exactly 12 eggs, not 50, no
  banking) against the real server clock path. No console errors. World-presence (Adult+Nest
  models, Assign/Collect prompts) is **not** built yet — deferred, see `backlog.md` item 6.

- **Added 2026-07-17 (backlog item 10, ad-hoc) — Food Shop:** `src/shared/Domain/BuyFoodRules.luau`
  (spec'd, mirrors `BuyEggRules.luau`), new `src/shared/Data/FoodShopConfig.json` price catalog
  (flat 10-gold placeholder per item, no schema/ADR needed since Food already reuses generic
  `Profile.inventory`), thin `src/server/Transactions/Economy/BuyFoodTransaction.luau`, and
  `src/client/Shop/FoodShopUI.luau` (Element-grouped, scrollable, mirrors `EggShopUI.luau`).
  **Live-verified in Studio, 2026-07-17:** direct `Transaction:InvokeServer` calls for buy/stack/
  unknown-item/invalid-amount all correct; also click-tested the real UI via simulated mouse input
  (open shop → click Buy on Fish → Gold `208,390→208,380`, status line confirmed). No console
  errors.

- **Added 2026-07-17 (backlog item 11, ad-hoc) — Adult Dragon world-presence + Inventory
  Baby/Adult breakdown:** `DragonSpawner.Spawn` now clones `ReplicatedStorage.DragonModels.Adult`
  (not just `.Baby`) and tags it `AdultDragon`; `RespawnAllBaby` renamed `RespawnAll`, now filters
  on `AssignedSlotId == nil` instead of `GrowthStage ~= "Adult"`; `init.server.luau`'s `FeedDragon`
  post-commit handler re-`Spawn`s the Adult model on `BecameAdult=true` instead of despawning with
  nothing. `EggInventoryUI.luau`'s dragon-count line now reads e.g. `Common Baby x5, Common Adult
  x10` instead of just `Common x15`. **This deliberately overrides item 5's original "Adults get
  no world presence until Farm Assignment" rule**, per direct user request — no schema/ADR change,
  purely Runtime-only display. **Live-verified in Studio, 2026-07-17:** fed a real `Baby_2` dragon
  to Adult via the `Transaction` remote, confirmed via `inspect_instance` the Nursery model swapped
  to the `AdultDragon`-tagged model with no `ProximityPrompt` and the correct billboard text;
  screenshot-confirmed multiple Adults visibly standing in the Nursery; screenshot-confirmed the
  real Inventory UI's Baby/Adult breakdown line. No console errors.

- **Updated 2026-07-17 (later same day, still item 11) — full dragon detail:** upgraded the coarse
  Baby/Adult bucket to Rarity + Element + exact `GrowthStage` everywhere it's displayed, per direct
  follow-up user request. `DragonSpawner` billboards now read e.g. `"Rare Fire - Baby_1 (Fed
  1/4)"`/`"Mythic Earth - Adult"` (new `Rarity`/`GrowthStage` attributes); `EggInventoryUI.luau`'s
  dragon line now groups by `` `{Rarity} {Element} {GrowthStage}` ``. Live-verified in Studio via
  `execute_luau` reading the exact billboard text and a screenshot of the Inventory UI. No console
  errors.

- **Added 2026-07-17 (backlog item 12, ad-hoc tooling) — ClearTestDragons debug harness:** wipes
  `profile.dragons`, resets every `profile.farmSlots` entry to empty, and despawns the Nursery —
  same pattern as `AddTestFood`/`AddTestDragon`. Live-verified: dragon count → 0, Nursery folder → 0
  children, assigning a deleted dragon UID correctly returns `DragonNotFound`.

- **2026-07-17 — Ingested `docs/GROW_A_DRAGONA_IMPLEMENTATION_GDD.md`** (user-supplied, a more
  detailed successor to `Doc/Grow_a_Dragona_GDD.txt`; copied verbatim into the repo so future
  sessions can cite it directly). This promoted three previously-flagged engineering placeholders to
  real, GDD-sourced design values — pure data changes, no schema/transaction-contract change, so no
  new ADR:
  - `DragonConfig.json` `elementOdds`: equal 20%/element → Fire/Water/Earth 25% each, Light/Dark
    12.5% each (GDD §2).
  - `ProductionConfig.json` `startingFarmSlots`: `3` (unsourced placeholder) → `2` (GDD §1/§6's
    stated starter-plot size). Existing saved profiles are unaffected — `ProfileSchema.default`
    only reads this value when creating a brand-new profile, and `ProfileSchema.validate` only
    falls back to it for a profile whose `farmSlots` field is entirely missing, not to shrink an
    already-larger stored value.
  - `FoodShopConfig.json`: flat `10` gold/item placeholder → flat `1` gold/item (GDD §11).
  Also surfaced net-new scope not previously tracked: the GDD's full paid Plot Expansion ladder
  (2→4→6→8→10→12 slots, 500/2,000/8,000/25,000/80,000 gold — `backlog.md` item 13, not started),
  concrete Sell Production Egg base values and the production-egg variant-odds-by-dragon-rarity
  table (both feed into item 7, not started), and the full 2/3/4/6/12-dragon synergy curve (item 8,
  not started, MVP scope still only requires the 2-dragon tier). No code/tests changed by this pass
  — `ci/run-tests.sh fast` should still read 18 specs; re-run after this entry to confirm.

- **Added 2026-07-17 (backlog item 14) — Farm Plot world-presence, auto Farm-Slot placement, and
  free starter Hatching Egg:** see `adr/ADR-005-farm-plot-and-starter-hatch.md` for the full design.
  `ci/run-tests.sh fast` → real `PASSED`, 19 specs (up from 18):
  - `ClaimHatchRules.luau` — a freshly-hatched dragon now auto-assigns to the lowest-numbered open
    `farmSlots` entry (or stays unassigned if every slot is full); 3 new spec cases prove this,
    including the already-occupied-slot and all-slots-full paths.
  - `FeedDragonRules.luau` — now takes a `now: number` parameter and, on the 4th Feed, auto-starts
    production (`ProductionStartedAt = now`) on the dragon's already-assigned slot; 3 new spec cases
    prove this fires only on `BecameAdult` with an assigned slot, and never touches `farmSlots`
    otherwise.
  - New `StarterHatchRules.luau` (+ 4-case spec) — `ShouldGrant`/`Stage`/`Commit` for the one-time
    free Hatching Egg, rolled from `EggConfig.hatchingTiers.Common.odds` (real odds, not scripted).
  - `ProfileSchema.luau` — new `meta.starterHatchGranted` with an asymmetric default (`false` from
    `.default()`, `true` when missing from `.validate()`) so pre-existing saves aren't retroactively
    granted a surprise egg; 3 new spec cases.
  `ci/compile-check.sh` → `COMPILE_OK`, `ci/lint.sh` → `PASSED`. New
  `src/server/Services/FarmPlotSpawner.luau` (engine-glue, no new pure logic): builds each player's
  physical Farm Plot from primitive Parts (a wood-plank tile per `farmSlots` entry, a 4-beam wooden
  fence sized to fit them) — no Toolbox/Studio-authored fence/tile asset exists yet, unlike
  `DragonModels`/`EggModels`. `DragonSpawner.Spawn` now positions an already-assigned dragon on its
  Farm Plot tile (falling back to the old Nursery-lane placeholder only when no slot was available
  at hatch time); `DragonSpawner.RespawnAll` now respawns every owned dragon regardless of
  `AssignedSlotId` (previously only unassigned ones), closing `ADR-004`'s deferred world-presence
  gap for the Adult-on-slot case. `init.server.luau`: builds the Farm Plot and grants the starter
  egg in `PlayerAdded` (before `LoadCharacterAsync`, so `HatchSpawner.RespawnAllPending` picks up the
  newly-granted pending hatch once the character loads); added an `AssignProducer` post-commit
  branch so a manual re-assignment also moves the dragon's world model; `FarmPlotSpawner.Despawn`
  added alongside the existing `HatchSpawner`/`DragonSpawner` despawn-on-leave calls.
  **Not Studio-verified this pass** — no Roblox Studio MCP session was available. Started
  `rojo serve default.project.json` (listening on `localhost:34872`) so the user's own Studio +
  Rojo plugin can connect; the fence/tile geometry, a fresh hatch landing visibly on slot 1, and the
  starter egg's world appearance/hatch still need a manual or MCP Studio pass to confirm.

## What's left

Backlog items 1, 2, 4, 5 (including Phase B world-presence, later overridden by item 11), 6
(Rules/Transaction layer only), 10 (Food Shop), 11 (Adult world-presence + full dragon-detail
display), 12 (ClearTestDragons), and 14 (Farm Plot + auto-placement + starter egg, Domain layer and
engine-glue written, **not yet Studio-verified**) are done. Item 3 (engine-lane activation ADR)
hasn't started. Items 7-9 and 13 (Plot Expansion) haven't started. Item 6's Nest-specific
world-presence (the egg-pile model itself, a Collect `ProximityPrompt`) remains open as a follow-up
pass — item 14 closed the Adult-dragon-on-its-slot half of item 6's original world-presence gap, but
not the Nest object. The test-harness vertical slice's manual Studio click-test is done for the
original harness (2026-07-14/15), the Buy Egg/Hatch/Feed transaction UIs (2026-07-15/16), the Food
Shop UI, and the Inventory Baby/Adult breakdown (2026-07-17) — no known outstanding gaps in any of
them. **Item 14 specifically still needs a Studio pass**: confirm the Farm Plot fence/tiles render
without overlap, a fresh hatch's Baby model visibly lands on Farm Slot 1 (not the old Nursery lane),
feeding it to Adult keeps it on that same tile with production now running, and a genuinely new
profile gets exactly one free Hatching Egg sitting on the plot that hatches at real Common odds.

## Known bugs

None found in the tested Domain layer. Fixed this week (not still open):
- 2026-07-17: `FarmPlotSpawner.buildFence` drew all 4 boundary beams as full-length, fully sealing
  the Farm Plot rectangle with no gap — a player had no way to walk in (user report: "farm đang
  không có lối vào farm"). Fixed by splitting the near (-Z, spawn-facing) beam into two segments
  around a centered `ENTRANCE_WIDTH` (8-stud) gap. Still not confirmed live in Studio (no player
  session to observe — see "What's left").
- 2026-07-14: a JS-style `${}` interpolation typo in the test helper, and `selene` crashing on Luau
  syntax without a `selene.toml` (tooling, not app bugs) — covered under Known gaps / techContext.md.
- 2026-07-14: `DataService`'s unguarded `GetDataStore` call crashed the whole server `require()`
  chain when DataStore was unavailable — fixed with `pcall`.
- 2026-07-15: a save on player-leave/shutdown could silently fail to persist (no `BindToClose`, no
  error logging) — fixed with `game:BindToClose` + `warn()` (see engine-glue layer entry above).
- 2026-07-15: `TransactionQueue.Run` crashed with "cannot spawn non-suspended coroutine with
  arguments" on the very first live transaction — fixed by deferring the queue's kickoff via
  `task.defer` instead of a synchronous call (see transaction-framework entry above).

## Known gaps in the scaffold itself

- `luau-lsp analyze` (via `ci/compile-check.sh`) now has real Roblox definitions wired in and
  catches ordinary type errors, but a verified-by-experiment limitation remains: it does not flag a
  nonexistent/mistyped method call on an `Instance`-derived value (e.g. a typo'd `DataStore` method).
  Don't treat a green compile-check as proof against that class of bug in `src/server/`/`src/client/`
  — see `memory-bank/techContext.md`.
- `DataService` save path is last-write-wins (`SetAsync`), not race-hardened — tracked as part of
  backlog item 9, not a bug in today's scope.
- `luau-lsp analyze`/`rojo build` cannot catch runtime-only DataStore-availability errors (proven
  2026-07-14: the unguarded `GetDataStore` crash passed compile-check clean but crashed the whole
  server script at runtime). Don't treat a green compile-check as proof against that class of bug
  either — same caveat as the `Instance`-method-typo gap above, different root cause.
- **Found 2026-07-15:** the Roblox Studio MCP's `execute_luau` on the `Server` datamodel does not
  reliably share Luau's `require()` module cache with the actually-running game — a `require`'d
  module's internal state came back empty/nil when introspected this way mid-Play-session even
  though the real game was actively using that same module correctly. Don't use ad-hoc server-side
  `execute_luau` state dumps as a verification method beyond quick read-only sanity checks; verify
  behavior through the real remote/UI surface instead (this is what caught the coroutine bug above
  cleanly, once the state-dump approach was abandoned).
- **Found 2026-07-16:** pressing Play in Studio snapshots whatever the **Edit-mode** DataModel
  currently holds; Rojo syncs file edits into Edit mode, not directly into an already-running Play
  session. Editing a file and immediately starting Play can race that sync — Play silently starts
  with the pre-edit data, no error. Confirm the new value via `execute_luau` on the `Edit`
  datamodel first, then start Play.
