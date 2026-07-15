# Active Context

> Always load. Current focus, last 3 done, current + next task. Overwrite this each `end-session`.

## Current focus

The vertical-slice test harness (Config + DataService + CurrencyService + InventoryService + text/
button UI) is now fully verified end to end in Studio, including real persistence across Stop/Start.
Ready to move on to backlog item 2 (Buy Egg transaction).

## Last 3 done (this session)

1. Confirmed Rojo auto-reconnected to a brand-new Studio place (`Place2`) with no manual sync step
   needed; re-verified the harness renders and behaves identically to the prior place.
2. Reproduced a real data-loss bug via Studio MCP: firing a test button then immediately stopping
   Play lost the change. Root cause: `DataService.Save`'s `SetAsync` is a yielding network call with
   nothing waiting for it before shutdown, and `Release`'s error return was discarded (silent
   failure, no console output).
3. Fixed `src/server/init.server.luau`: added `game:BindToClose(...)` to hold shutdown until every
   connected player's profile is released/saved, and `warn(...)` on save failure in both the
   `PlayerRemoving` and `BindToClose` paths. Reverified `ci/compile-check.sh` (`COMPILE_OK`) and
   `ci/run-tests.sh fast` (`PASSED` ×4), then re-tested live in Studio 3x (fire button → immediate
   stop → restart) — gold/food now persist correctly every time.

## Current task

Memory write-back for this session (this update).

## Next task

Backlog item 2 (Buy Egg transaction): needs the egg-price lookup against `EggConfig.json`, the
`BuyEggTransaction.luau` module itself, and its spec (Gold deduction + egg grant commit atomically;
duplicate request ID can't double-grant). `CurrencyService.SpendGold` and `InventoryService.AddItem`
are already there to build on; `DataService` is now hardened against the shutdown-data-loss bug
found this session.
