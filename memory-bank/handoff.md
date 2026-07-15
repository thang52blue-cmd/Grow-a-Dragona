# Handoff

> Always load, read first. Last session's state transfer. Overwritten each `end-session`.

## Session: 2026-07-15 — Golden path verified; save-on-shutdown data-loss bug found and fixed

**Verified state:** All three gates still green: `ci/compile-check.sh` → `COMPILE_OK`,
`ci/run-tests.sh fast` → `PASSED` (4 specs), unchanged count. User enabled `Studio Access to API
Services` in their place's Game Settings (Studio-UI-only toggle, not scriptable — done manually on
their end), which unblocked real DataStore reads/writes for the first time.

**What happened:**

1. User opened a brand-new Studio place (`Place2`) to replace the earlier `Place1`. Rojo's plugin
   auto-reconnected to the already-running `rojo serve` session with no action needed — confirmed via
   MCP (`ReplicatedStorage.Shared`, `ServerScriptService.Server` etc. already present, Rojo dock
   widgets open). Re-ran the same click-test from the prior session inside `Place2` to confirm parity;
   identical behavior (`Remotes` created, harness renders, graceful `lastError` text, no crash).
2. User enabled `Studio Access to API Services` themselves (File → Game Settings → Security) and
   manually tested `+10 Gold` / `+1 Fish` via the UI. Reported: after Stop → Start, the gold/food
   values were not persisted.
3. Repro'd via Studio MCP: fired `AddTestGold` then immediately called `start_stop_play(false)` with
   no delay, then restarted and inspected `PlayerGui.TestHarness.StatusLabel`. Root cause found:
   `Players.PlayerRemoving` called `DataService.Release` → `Save` → `SetAsync` (a real, yielding
   network call), but nothing in `src/server/init.server.luau` waited for that call to finish before
   the server VM tore down, **and** `Release`'s `(ok, err)` return was discarded — a failed save on
   disconnect was completely silent, no console output anywhere. This matches the exact symptom
   reported (data silently missing, no error visible).
4. Fixed in `src/server/init.server.luau`: added `game:BindToClose(...)` that calls
   `DataService.Release` for every still-connected player before the server is allowed to fully shut
   down (the standard Roblox pattern for guaranteeing pending DataStore writes complete), and added
   `warn(...)` calls on both the `PlayerRemoving` path and the `BindToClose` path so a future save
   failure is visible in the Output window instead of silent. Reran `ci/compile-check.sh`
   (`COMPILE_OK`) and `ci/run-tests.sh fast` (`PASSED` ×4) after the edit — this file has no Lune spec
   (engine glue, per AGENTS.md's deferred lane; `game:BindToClose` isn't Lune-testable).
5. Re-verified live in Studio via MCP: fired `AddTestGold` + `AddTestFood`, called stop immediately
   (no delay) 3 separate times across this session, restarted each time — values persisted correctly
   every time (`Gold: 10→20→30`, `Fish: 1→1→2`), no `warn()` output. Golden path (not just the error
   path) is now proven end to end: buttons → services → DataStore → persists across Stop/Start.

**Do next:** backlog item 2 (Buy Egg transaction) — `CurrencyService.SpendGold`/
`InventoryService.AddItem` and the now-hardened `DataService` are ready to build on. No more known
outstanding gaps in the test-harness vertical slice itself.

**Environment note (unchanged):** `rojo serve` keeps running across Studio place changes/sessions
without needing a restart. Bash tool needs `export PATH="$PATH:/c/Users/Minh Anh/.rokit/bin"`
prefixed before `ci/*.sh` calls in this environment.
