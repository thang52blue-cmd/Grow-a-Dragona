# Active Context

> Always load. Current focus, last 3 done, current + next task. Overwrite this each `end-session`.

## Current focus

Backlog item 2 (Buy Egg transaction) is done and verified live in Studio. The transaction
framework built for it (PayloadValidator, RateLimiter, RequestCache, TransactionQueue,
TransactionService, PlayerRuntimeStore) is meant to be reused as-is for every future transaction
type — adding the next one (backlog item 4, Start Hatch/Claim Hatch) should only need a new pure
`*Rules.luau` module + a thin handler, not new framework code.

## Last 3 done (this session)

1. Built the full Buy Egg transaction vertical slice: pure `BuyEggRules` (+ spec covering the
   plan's success/existing-stack/insufficient-gold/malformed-payload cases) under
   `src/shared/Domain/`, plus the reusable engine-glue framework (`PlayerRuntimeStore`,
   `TransactionQueue`, `TransactionService`) and the `BuyEggTransaction` handler under
   `src/server/`. Extended the client test harness with Buy Egg / Retry-last-request buttons.
2. Got all three CI gates green (`COMPILE_OK`, fast tests `PASSED` ×12, lint `PASSED`), fixing two
   real `luau-lsp` strict-mode issues along the way (a `Rarity` literal-union widening bug from
   casting an `any` payload field, and over-destructuring a 0-return-value `pcall`).
3. Live-verified in Studio via the Roblox Studio MCP: found and fixed a real bug that only showed
   up at runtime (`cannot spawn non-suspended coroutine with arguments` in `TransactionQueue.Run` —
   `processNext` was kicked off before the caller thread had actually yielded). After the fix,
   confirmed live: successful purchase with correct atomic Gold/egg deltas, duplicate-RequestId
   dedupe (same cached result, no double-charge), invalid-amount/invalid-rarity rejection,
   rate-limit rejection under burst, and insufficient-gold rejection once the rate-limit window
   cleared. No console errors from game code.

## Current task

Memory write-back for this session (this update).

## Next task

Either backlog item 3 (engine-lane activation ADR) or item 4 (Start Hatch / Claim Hatch
transactions) — see `memory-bank/backlog.md`. Note for item 4: `TransactionType.StartHatch` (20)
and `ClaimHatch` (21) ids already exist in `src/shared/Domain/TransactionType.luau` (reserved,
unused) so no new ids need inventing. Hatch state (a "hatching egg" turning into a dragon after a
timer) will need a small profile-schema addition (dragons owned, in-progress hatch jobs) that
*does* clear AGENTS.md's "changing live save schemas" gate this session deliberately avoided for
Buy Egg — plan to stop and ask before adding those fields, or write the ADR AGENTS.md asks for.
