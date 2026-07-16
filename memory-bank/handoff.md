# Handoff

> Always load, read first. Last session's state transfer. Overwritten each `end-session`.

## Session: 2026-07-17 (continued again) — Adult Dragon world-presence + Inventory Baby/Adult breakdown

**Verified state:** All three gates green: `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh
fast` → `PASSED` (18 specs, unchanged — engine-glue/UI only), `ci/lint.sh` → `PASSED`.
**Live-verified in Studio Play mode via the Roblox Studio MCP, including screenshots of the world
model and the Inventory UI.** This work is **on top of** the Food Shop session above (committed as
`623bec9`) and is **not yet committed itself**.

**What happened:**

1. User asked (in Vietnamese) for two things: (a) after a Baby Dragon is fed enough to become
   Adult, the Adult should be shown there (currently it just despawned with nothing) — mentioning
   a possible future evolution animation as a "later" idea, not now; (b) the Inventory panel
   should clearly show dragon counts per type, distinguishing Baby vs. Adult, for easier MVP
   debugging.
2. Checked whether (a) was a schema/ADR-gated change: no — it's purely Runtime-only world-presence
   (which model gets cloned, which tag/prompt it gets), no new persistent fields, so no ADR was
   needed. Confirmed via the Roblox Studio MCP that `ReplicatedStorage.DragonModels.Adult` was
   already staged (alongside `.Baby`) before writing any code — no new asset work required.
3. Noted explicitly that this **overrides item 5's originally-implemented "Adults get no world
   presence until Farm Assignment" rule**, itself taken from `docs/prd/core-game-loop.md`'s
   Recommended MVP rule. Did not edit the PRD doc (kept as the saved-verbatim historical record
   per its own header comment) — instead documented the deviation in `memory-bank/backlog.md` as a
   new item (11), same treatment as other deviations from the plan doc (instant hatch, Rarity
   reuse, etc.).
4. Implemented:
   - `src/server/Services/DragonSpawner.luau`: `Spawn` now branches on `dragon.GrowthStage ==
     "Adult"` — clones `DragonModels.Adult` instead of `.Baby`, tags the clone `AdultDragon`
     (new tag, distinct from `BabyDragon`) instead of adding a `ProximityPrompt` (nothing to feed
     on an Adult yet), and shows a `"{Element} Dragon (Adult)"` billboard instead of `Fed X/4`.
     Extracted a small `addStatusBillboard` helper so both branches share the same
     BillboardGui/TextLabel construction. `RespawnAllBaby` renamed to `RespawnAll`; its filter
     changed from `dragon.GrowthStage ~= "Adult"` to `dragon.AssignedSlotId == nil` — so an Adult
     not yet assigned to a Farm Slot now also reappears in the Nursery on rejoin, while one that
     *is* assigned (via the item-6 test remotes) correctly still gets no Nursery model (its
     presence belongs at the Farm Slot, a still-unbuilt follow-up).
   - `src/client/Dragon/FeedPromptController.luau` needed **no changes** — it only ever attaches
     to the `BabyDragon` tag via `CollectionService`, so it was already guaranteed to never see an
     `AdultDragon`-tagged model; confirmed live (no Feed prompt appeared on the Adult).
   - `src/server/init.server.luau`'s `FeedDragon` post-commit handler: on `BecameAdult=true`, now
     `Despawn`s the Baby model then looks up the just-committed dragon record
     (`profile.dragons[result.Data.DragonUID]`, same pattern `ClaimHatch`'s handler already uses)
     and `Spawn`s it again — `Spawn` picks the Adult model this time since the record's
     `GrowthStage` is now `"Adult"`.
   - `src/client/Inventory/EggInventoryUI.luau`: the dragon-count aggregation key changed from
     `dragon.Rarity` alone to `` `{dragon.Rarity} {Baby|Adult}` `` (collapsing the 5 `GrowthStage`
     values to a binary bucket, since the user asked for "baby hay adult," not the exact stage),
     iterated in a fixed `RARITY_ORDER × {Baby, Adult}` order for a stable display.
5. Ran all 3 CI gates green on the first try (no stylua nits this time).
6. **Live-verified in Studio Play mode via the Roblox Studio MCP:** confirmed the edited
   `DragonSpawner.luau`/`init.server.luau`/`EggInventoryUI.luau` synced into Edit-mode first, then
   started Play. Fired `AddTestFood`, found an existing `Baby_2` dragon (`DragonUID=5`, Fire) in the
   live profile snapshot, fed it twice via real `Transaction:InvokeServer` calls
   (`FeedCount 2→3→4`, `BecameAdult=true` on the second). Used `inspect_instance` on
   `Workspace.Nursery.<exact UserId>.5` (wildcard paths like `Nursery.*.5` do **not** work with this
   tool — needed the player's literal `UserId`) to confirm: `CollectionService` tags were
   `AdultDragon` (not `BabyDragon`), no `ProximityPrompt` descendant existed, and the `FeedStatus`
   billboard read `"Fire Dragon (Adult)"`. Took two screenshots confirming multiple `"Fire Dragon
   (Adult)"`-labeled models standing in the Nursery next to `Fed 0/4`-labeled Baby models. Opened
   the real Inventory UI via simulated mouse click and screenshotted it: the Dragons line read
   `Common Baby x5, Common Adult x10, Rare Adult x4, Epic Baby x1, Epic Adult x2, Legendary Baby
   x2, Legendary Adult x4, Mythic Baby x2, Mythic Adult x1` — exactly the requested breakdown.
   `get_console_output` showed no errors at any point. Stopped Play mode afterward.
7. Updated `memory-bank/backlog.md` (new item 11, `~~DONE~~`), `progress.md`, `activeContext.md`,
   and this `handoff.md`. **Not yet committed** — user hadn't been asked yet as of this write-back.

**Deviations / judgment calls (not user-specified, worth restating):**
- This session's core premise **is itself a deviation** from item 5's originally-implemented rule
  (Adults get no world presence until Farm Assignment) — done deliberately per direct user
  instruction, not a bug fix. `docs/prd/core-game-loop.md` is left unedited as the historical
  saved-verbatim plan; actual behavior now differs from it, documented in `backlog.md` item 11.
- Collapsed the 5-value `GrowthStage` (`Baby_0`...`Baby_3`, `Adult`) to a binary `Baby`/`Adult`
  bucket for the Inventory display, rather than showing every exact stage — matches the user's
  literal ask ("rồng bé hay rồng trưởng thành," baby-or-adult) without over-showing detail that
  wasn't requested. `DragonSpawner`'s world model still shows the precise `FeedCount` (`Fed X/4`)
  for Babies, so exact-stage detail isn't lost, just not duplicated in the Inventory text line.
- No evolution animation was built — the user explicitly framed it as a "maybe later" idea, not
  part of this ask. The model swap is an instant Despawn+Spawn with no transition effect.
- An Adult *assigned to a Farm Slot* still gets no world model at all (Nursery model removed once
  `AssignedSlotId` is set, and Farm-Slot-side world-presence isn't built) — this session only
  changed the Nursery's own display of not-yet-assigned Adults, not backlog item 6's own deferred
  world-presence follow-up.

**Do next:**
1. Ask the human whether to commit this work now (same pattern as the rest of today's sessions).
2. Backlog item 6's Farm-Slot-specific world-presence pass (Adult+Nest models once assigned to a
   slot, Assign/Collect prompts) is still open — see the item-6 session's notes further down this
   file for the reuse plan.
3. Item 7 (Sell Production Egg) is next after that; item 3 remains open/unblocked otherwise.
4. If the human wants the "evolution animation" mentioned as a future idea, that's new unscoped
   work — ask what it should look like before implementing.

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions — verify with `tasklist`/`curl localhost:34872/api/rojo` before assuming
it's up. Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"` prefixed before
`ci/*.sh` calls. Confirm changed files sync into the **Edit-mode** DataModel before starting Play.
**New this session:** `inspect_instance` needs the exact `Workspace` path with the player's literal
numeric `UserId` — wildcard segments (e.g. `Workspace.Nursery.*.5`) return "Could not find any
instances," not a wildcard match; fetch the real `UserId` first (e.g.
`Players.LocalPlayer.UserId` via `execute_luau`) and build the exact path.

## Session: 2026-07-17 (continued) — Food Shop (Buy Food transaction, ad-hoc user request)

**Verified state:** All three gates green: `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh
fast` → `PASSED` (18 specs, up from 17), `ci/lint.sh` → `PASSED`. **Live-verified in Studio Play
mode via the Roblox Studio MCP, including a real click-test of the new UI (not just the remote).**
This work is **on top of** the item 6 session below (already committed as `a492c46`) and is **not
yet committed itself**.

**What happened:**

1. User asked (in Vietnamese) to add per-element Food items to the shop so players can buy them.
   Before implementing, checked whether this was already planned anywhere: it was not —
   `memory-bank/backlog.md` had no item for it, `docs/prd/core-game-loop.md` only ever called for
   "a temporary Food test source" (Buy Food explicitly deferred), and the GDD's Food section
   (§3.1) has no price/cost numbers at all. This is genuine new scope, not a gap-fill.
2. Determined no ADR/schema-approval gate applied here (unlike item 6 earlier today): Food already
   reuses the generic `Profile.inventory` bucket per ADR-003's existing precedent, so adding a Buy
   Food transaction needs no new persistent fields — only a new price config and transaction, same
   shape as the already-existing `BuyEggTransaction`. Proceeded without stopping to ask, per the
   user's stated preference for reasonable defaults over formal approval gates when nothing
   schema-level is at stake — but flagged the one placeholder decision (price) prominently instead
   of silently inventing it.
3. Implemented, mirroring `BuyEggRules.luau`/`BuyEggTransaction.luau`/`EggShopUI.luau` structurally:
   - `Types.FoodShopConfig = {[string]: number}`; `TransactionType.BuyFood = 11` (Economy group,
     next to `BuyEgg=10`); `TransactionCode.InvalidFoodType = 13` (next in the 10-19 "type" block).
   - `src/shared/Data/FoodShopConfig.json` — flat `{itemId: goldPrice}` for all 15 food items
     across the 5 elements, **every price a flat 10-gold placeholder** (no design source exists).
     Deliberately a separate file from `FoodConfig.json` rather than changing that file's shape —
     `FeedDragonRules` already depends on `FoodConfig.json`'s existing `{[Element]: {string}}`
     array shape and changing it would have rippled into unrelated Feed logic for no reason.
   - `src/shared/Domain/BuyFoodRules.luau` (+ `.spec.luau`, 7 cases) — pure Validate/Stage/Commit,
     structurally identical to `BuyEggRules.luau` (Currency.spend + Inventory.add in one Stage,
     Commit applies both atomically).
   - `src/server/Transactions/Economy/BuyFoodTransaction.luau` — thin handler, registered in
     `init.server.luau` with a 10-per-2s rate limit (same as Feed/Assign/Collect).
   - `src/client/Shop/FoodShopUI.luau` — new panel grouped by Element (`Elements.List` order) in a
     `ScrollingFrame` (15 items don't fit a fixed-height frame like the 5-row Egg Shop does),
     mirrors `EggShopUI.luau`'s row/price/Buy-button/status-line pattern exactly. Wired into
     `init.client.luau` next to `EggShopUI.Init`.
4. Ran all 3 CI gates; `stylua` flagged 1 file (spec-only formatting), auto-fixed, re-verified
   green.
5. **Live-verified in Studio Play mode via the Roblox Studio MCP:** confirmed new modules synced
   into Edit-mode DataModel first, then started Play. Direct `Transaction:InvokeServer` calls: a
   successful `ChiliPepper x3` buy (`TotalPrice=30`, stacked onto a pre-existing balance from an
   earlier session's `AddTestFood` calls), a second buy stacking further, an unknown item ID →
   `InvalidFoodType` (13), a negative Amount → `InvalidAmount` (20), and a different element's item
   (`Honey`) succeeding independently. **Additionally click-tested the real UI** via
   `user_mouse_input` + `screen_capture` (not done for any prior feature this thoroughly): clicked
   the new "Food Shop" button, screenshotted the open panel (confirmed Element headers/prices/Buy
   buttons render correctly, `ScrollingFrame` scrolls), clicked "Buy" on the Fish row, and
   screenshotted again — Gold visibly went `208,390 → 208,380` and the status line read "Bought 1
   Fish for 10 gold." live in the actual UI. `get_console_output` showed no errors both times.
   Stopped Play mode afterward.
6. Updated `memory-bank/backlog.md` (new item 10, `~~DONE~~`), `progress.md`, `activeContext.md`,
   and this `handoff.md`. **Not yet committed** — user hadn't been asked yet as of this write-back.

**Deviations / judgment calls (not user-specified, worth restating):**
- Food prices are a flat 10-gold-per-item placeholder invented for this session — genuinely no
  design source (GDD, PRD, or backlog) specifies any Food price. Needs real balancing before ship.
- `TransactionType.BuyFood = 11` placed directly after `BuyEgg = 10` (both Economy-shop
  transactions); `TransactionCode.InvalidFoodType = 13` placed in the existing 10-19 "invalid type"
  block rather than starting a new numeric range.
- No per-item `enabled`/`maxPurchaseAmount` fields were added to `FoodShopConfig.json` (unlike
  `EggConfig.json`'s hatching tiers) — no stated requirement for disabling individual food items or
  capping bulk purchases yet; added only what item 10's literal ask required. Revisit if the human
  wants shop-side feature flags later.
- Kept `FoodShopConfig.json` as a brand-new file rather than folding a price field into
  `FoodConfig.json`'s existing per-element array shape, specifically to avoid touching
  `FeedDragonRules.luau` (which already depends on that exact shape) for an unrelated feature.

**Do next:**
1. Ask the human whether to commit this Food Shop work (same pattern followed for item 6 earlier
   today) before starting anything else.
2. Backlog item 6's world-presence pass (Adult Dragon + Nest models, Assign/Collect prompts) is
   still open — see this file's item-6 section below for the reuse plan
   (`DragonSpawner`'s Nursery-lane pattern + `ReplicatedStorage.NestModels.Default`).
3. Backlog item 7 (Sell Production Egg) is next per priority order otherwise.
4. Real Food pricing needs balancing before ship (see Deviations above).

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions — verify with `tasklist`/`curl localhost:34872/api/rojo` before assuming
it's up. Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"` prefixed before
`ci/*.sh` calls. Confirm new files sync into the **Edit-mode** DataModel via `search_game_tree`
before starting Play. The `Transaction` remote requires a numeric `requestId`. **New this session:**
`mcp__Roblox_Studio__user_mouse_input` (with `instance_path`, e.g.
`LocalPlayer.PlayerGui.FoodShopGui.OpenFoodShopButton`) combined with `screen_capture` reliably
click-tests a UI end-to-end in Play mode (not just its underlying remote) — use this for future
UI-facing features, it caught nothing wrong here but is a strictly stronger verification than
calling `Transaction:InvokeServer` directly from a script.

## Session: 2026-07-17 — Backlog item 6: Assign Producer / Collect Nest (Rules/Transaction layer)

**Verified state:** All three gates green: `ci/compile-check.sh` → `COMPILE_OK`, `ci/run-tests.sh
fast` → `PASSED` (17 specs, up from 14 — 3 new pure Domain spec files), `ci/lint.sh` → `PASSED`
(after `stylua` auto-formatted 3 files it flagged). **Live-verified in Studio Play mode via the
Roblox Studio MCP.**

**What happened:**

1. User asked to restart the Rojo server (it wasn't running) and continue work. Restarted `rojo
   serve` in the background, confirmed it's listening on `localhost:34872` (`curl`/`tasklist` both
   confirmed a real `rojo.exe` process and a valid `/api/rojo` response for project `GrowADragona`).
2. Per `activeContext.md`'s "next task", picked backlog item 6 (Assign Producer and Collect Nest
   transactions). This changes the save schema (`DragonRecord.AssignedSlotId`, two new `Profile`
   sections), which `AGENTS.md` and `adr/ADR-003-feed-dragon-schema.md` both explicitly gate on
   human approval + an ADR — stopped and asked before writing any code.
3. Drafted `adr/ADR-004-farm-slot-and-nest-schema.md` from `docs/prd/core-game-loop.md`'s
   Persistent Data Model / Server Services sections (already the approved reference spec), flagged
   the one open design item (starting Farm Slot count — the PRD never specifies a number) as my own
   placeholder proposal (3, all pre-unlocked), and asked the user via `AskUserQuestion`. **Approved
   as proposed.**
4. Implemented, in order:
   - `Types.luau`: `DragonRecord.AssignedSlotId: number?`, new `FarmSlot`/`ProductionEggInventory`/
     `ProductionConfig` types, `Profile.farmSlots`/`productionEggInventory`.
   - `TransactionType.AssignProducer = 31`; `TransactionCode`s `SlotNotFound=43`,
     `SlotOccupied=44`, `DragonNotAdult=45`, `DragonAlreadyAssigned=46`, `NestEmpty=47`.
   - `src/shared/Data/ProductionConfig.json` (180s interval, 12-egg capacity, 3 starting slots) +
     README entry.
   - `ProfileSchema.luau`: `default()` now takes `startingFarmSlots` and pre-populates that many
     empty slots; `validate()` now takes an optional `startingFarmSlots` for backward-compat
     defaulting, and validates/defaults `farmSlots`/`productionEggInventory`/`AssignedSlotId` as
     additive fields (same precedent as every prior additive field). Updated call sites
     (`DataService.luau`) and existing specs (`ProfileSchema.spec.luau`) for the new signature,
     plus added new spec cases for the new fields.
   - `FeedDragonRules.luau`/`ClaimHatchRules.luau`: preserve/default `AssignedSlotId` when writing a
     `DragonRecord` (Feed) or creating one (Claim, defaults `nil`) — required now that the field is
     part of the type.
   - New pure Domain modules (all spec'd): `ProductionRules.luau` (timestamp→completed-cycles
     calc, the PRD's suggested formula verbatim, capacity-capped, no excess-cycle banking),
     `AssignProducerRules.luau`, `CollectNestRules.luau` (calls `ProductionRules.Advance` before
     reading a slot, so a Collect never misses cycles completed since the last write).
   - Thin handlers `src/server/Transactions/Production/AssignProducerTransaction.luau` +
     `CollectNestTransaction.luau` (removed the folder's `.gitkeep`), registered both in
     `init.server.luau` with per-type rate limits (10/2s, matching Feed/Claim).
   - Test-only harnesses in `RemotesSetup.luau`/`init.server.luau`, mirroring `AddTestFood`'s
     pattern exactly: `AddTestDragon` (grants an already-Adult, unassigned dragon — no fast path
     exists to reach Adult otherwise) and `FastForwardProduction` (rewinds a slot's
     `ProductionStartedAt` so completed-cycle math can be exercised without waiting the real 180s).
5. Ran all 3 CI gates; `stylua` flagged 3 files for formatting (not logic), auto-fixed, re-verified
   green.
6. **Live-verified in Studio Play mode via the Roblox Studio MCP** (real client
   `Transaction:InvokeServer` calls from the **Client** datamodel): confirmed new modules synced
   into the **Edit-mode** DataModel first, then started Play. `AddTestDragon` granted dragon `59`
   (Adult, unassigned). `AssignProducer(DragonUID=59, SlotId=1)` succeeded
   (`Data={DragonUID="59",SlotId=1}`). Then, in one batch: assigning a different Adult (`58`) to the
   now-occupied slot 1 → `SlotOccupied` (44); re-assigning `59` to slot 2 → `DragonAlreadyAssigned`
   (46); assigning a Baby dragon (`40`) to slot 3 → `DragonNotAdult` (45); assigning to slot `99` →
   `SlotNotFound` (43); collecting slot 1 with zero elapsed time → `NestEmpty` (47). All 5 codes
   matched exactly. `FastForwardProduction(1, 630)` (3.5 intervals) then `CollectNest(SlotId=1)` →
   `EggsCollected=3` (floor of 3.5, not 3.5 or 4). An immediate second collect → `NestEmpty` again.
   `FastForwardProduction(1, 9000)` (50 intervals, deliberately way past the 12-egg capacity) then
   `CollectNest` → `EggsCollected=12` exactly (not 50) — confirms the "do not bank excess elapsed
   cycles" rule live, not just in the pure spec. A third immediate collect after the capacity-capped
   one → `NestEmpty` again (confirms `ProductionStartedAt` correctly reset to collection time, not
   left stale). `get_console_output` showed no game-code errors/warnings throughout. Stopped Play
   mode afterward.
7. Updated `memory-bank/backlog.md` (item 6 now `~~DONE~~`, DoD-met note), `progress.md`,
   `activeContext.md`, and this `handoff.md`. Not yet committed.

**Deviations / judgment calls (not user-specified, worth restating):**
- Starting Farm Slot count (3, all pre-unlocked, no unlock economy) is an engineering placeholder I
  proposed and the user approved — the PRD never specifies a number. Revisit if the GDD later adds
  a slot-unlock economy.
- `TransactionType.AssignProducer = 31` was placed in the gap between `FeedDragon=30` and
  `CollectNest=40` (grouped with the other single-dragon-lifecycle transaction) rather than
  renumbering the already-reserved `CollectNest=40`/`SellProductionEgg=41` block.
- No "Remove from Farm Slot" transaction was built (PRD mentions `Adult_Unassigned` as a reachable
  state, but item 6's DoD doesn't require it) — `AssignedSlotId` being nilable means this can be
  added later with no further schema change.
- World-presence (spawning the Adult Dragon + Nest models, an Assign trigger, a Collect
  `ProximityPrompt`) was **deliberately not built this session** — same split as backlog item 5's
  Rules/Transaction-then-Phase-B pattern, stated explicitly in `ADR-004`'s Consequences section.
  There is currently no in-game (non-MCP-test-remote) way for a player to trigger Assign/Collect.

**Do next:**
1. Item 6's world-presence pass (if the human wants it next): reuse `DragonSpawner`'s Nursery-lane/
   tag/`ProximityPrompt` pattern, clone from `ReplicatedStorage.NestModels.Default` (already staged
   in Studio per `memory-bank/systemPatterns.md`). No schema change needed.
2. Backlog item 7 (Sell Production Egg transaction) is next per priority order otherwise — builds
   directly on `Profile.productionEggInventory`.
3. Backlog item 3 (engine-lane activation ADR) remains open/unblocked if the human wants to switch
   lanes instead.
4. This session's work is **not yet committed** — commit it (new files: `adr/ADR-004-...`,
   `src/shared/Data/ProductionConfig.json`, `src/shared/Domain/ProductionRules.luau`/`.spec.luau`,
   `AssignProducerRules.luau`/`.spec.luau`, `CollectNestRules.luau`/`.spec.luau`,
   `src/server/Transactions/Production/AssignProducerTransaction.luau`/`CollectNestTransaction.luau`;
   edited: `Types.luau`, `TransactionType.luau`, `TransactionCode.luau`, `ProfileSchema.luau`/
   `.spec.luau`, `FeedDragonRules.luau`, `ClaimHatchRules.luau`, `DataService.luau`,
   `RemotesSetup.luau`, `init.server.luau`, `src/shared/Data/README.md`, and the memory-bank files
   above) before starting item 6's world-presence or item 7.

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions/machine restarts — **verify with `tasklist`/`curl localhost:34872/api/rojo`
before assuming it's up**. Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"`
prefixed before `ci/*.sh` calls in this environment. After editing a data/script file, don't press
Play immediately — confirm new files/values read back correctly in the **Edit** datamodel via
`search_game_tree`/`execute_luau` first, *then* start Play (done this session: confirmed
`ProductionConfig`/`ProductionRules`/`AssignProducerRules`/`CollectNestRules`/both new transaction
modules appeared before Play started). **New this session:** the `Transaction` RemoteFunction
requires a numeric `requestId` (`PayloadValidator.IsPositiveInteger` in
`TransactionService.Submit`) — passing a string requestId (e.g. `"test-assign-1"`) silently returns
generic `InvalidRequest` (code 1) with no indication the requestId itself was the problem; always
use a plain integer when driving `Transaction:InvokeServer` manually via MCP.
