# Active Context

> Always load. Current focus, last 3 done, current + next task. Overwrite this each `end-session`.

## Current focus

Backlog items 1, 2, 4, 5 (world-presence included), 6 (Rules/Transaction layer), and 10 (Food Shop,
ad-hoc) are complete. A player can now buy Food for Gold from a real in-game shop UI — previously
Food could only be granted via the `AddTestFood` debug remote. **World-presence for item 6 (Adult
Dragon + Nest world models, Assign/Collect `ProximityPrompt`s) is still not built** — no change this
session.

**Everything for item 6 was driven by `docs/prd/core-game-loop.md`.** Item 10 (Food Shop) was a
direct ad-hoc user request with **no existing design source** — no GDD section, PRD section, or
backlog item planned it; prices are a flat placeholder (10 gold/item), not GDD-sourced. See
`src/shared/Data/README.md`'s `FoodShopConfig.json` entry.

## Last 3 done (2026-07-17 session, second half)

1. User asked to add a Food Shop (buy Food per dragon element). Confirmed via research this was
   genuinely undesigned (no GDD price, no PRD transaction, no backlog item) before proceeding —
   this did **not** need an ADR since Food already reuses the generic `Profile.inventory` bucket
   (ADR-003 precedent), so no schema change was involved.
2. Implemented: `TransactionType.BuyFood = 11`, `TransactionCode.InvalidFoodType = 13`, new
   `src/shared/Data/FoodShopConfig.json` (flat 10-gold placeholder per item, all 15 items),
   `src/shared/Domain/BuyFoodRules.luau` + spec (18 specs total now), thin
   `src/server/Transactions/Economy/BuyFoodTransaction.luau`, and
   `src/client/Shop/FoodShopUI.luau` (Element-grouped `ScrollingFrame`, mirrors `EggShopUI.luau`),
   wired into `init.client.luau`/`init.server.luau`. All 3 CI gates green.
3. Live-verified in Studio Play mode via the Roblox Studio MCP: direct `Transaction:InvokeServer`
   calls for a successful buy, a stacking re-buy, an unknown item (`InvalidFoodType`), and an
   invalid amount (`InvalidAmount`) all returned correct codes/data — **and** click-tested the
   actual `FoodShopUI` via simulated mouse input (screenshot-confirmed): opened the shop, clicked
   Buy on Fish, Gold went `208,390→208,380`, status line read "Bought 1 Fish for 10 gold." No
   console errors.

## Current task

Memory write-back for this session (this update). This session's Food Shop work is **not yet
committed** (backlog item 6 from earlier in the day already was, in commit `a492c46`).

## Next task

1. Ask the human whether to commit the Food Shop work now (same "always ask before commit" pattern
   as item 6 earlier today).
2. Item 6's world-presence pass (Adult Dragon + Nest models, Assign/Collect prompts) is still the
   next planned-backlog item if the human wants to continue in priority order — see the previous
   session's notes below/`backlog.md` item 6.
3. Item 7 (Sell Production Egg transaction) is next after that; item 3 (engine-lane activation ADR)
   remains open/unblocked if the human wants to switch lanes.
4. Real Food pricing (currently a flat 10-gold-per-item placeholder) needs actual balancing before
   ship — flagged the same way `elementOdds`/`hatchDurationSeconds` placeholders were.

**Environment note (unchanged, restate every session):** `rojo serve` does NOT reliably stay
running across sessions — verify with `tasklist`/`curl localhost:34872/api/rojo` before assuming
it's up. Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"` prefixed before
`ci/*.sh` calls. Confirm new files sync into the **Edit-mode** DataModel (via `search_game_tree`)
before starting Play. The `Transaction` remote requires a numeric `requestId`
(`PayloadValidator.IsPositiveInteger`) — a string requestId silently fails with generic
`InvalidRequest` (code 1). New this session: `mcp__Roblox_Studio__user_mouse_input` with
`instance_path` (e.g. `LocalPlayer.PlayerGui.FoodShopGui.OpenFoodShopButton`) + `screen_capture`
worked well to click-test a UI end-to-end (not just invoke the remote directly) — worth reusing for
future UI-facing features instead of only testing the transaction layer.
