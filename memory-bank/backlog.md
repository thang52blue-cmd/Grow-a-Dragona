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

5. **Feed Dragon and growth calculation**
   DoD: spec proves growth rate differs correctly for correct-element vs. wrong/no food; spec proves
   Baby→Adult only triggers at the defined threshold, not before.

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
