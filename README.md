# Grow-a-Dragona

A Roblox creature-raising and economy game built code-first with strict Luau and Rojo.

Players buy eggs, hatch dragons, feed them into adulthood, assign them to production or display,
collect output, sell it for Gold, and reinvest into better eggs and upgrades.

```text
Buy Egg → Hatch → Feed → Grow → Produce/Display → Collect → Sell → Repeat
```

## MVP goals

- Prove a satisfying hatch-to-production progression loop.
- Keep all valuable state server-authoritative.
- Prevent common duplication and forged-reward exploits.
- Make progression logic testable without Roblox Studio.
- Keep balance values in data files rather than hardcoded in logic.

## Architecture

The project separates pure domain logic from Roblox engine glue.

| Path | Responsibility |
|---|---|
| `src/shared/Domain/` | pure growth, hatch, reward, production, and validation logic |
| `src/shared/Data/` | prices, timings, odds, food values, production rates, bonuses |
| `src/shared/Types/` | shared typed records and identifiers |
| `src/server/Transactions/` | server-authoritative economy and progression transactions |
| `src/server/Persistence/` | profile loading, session lock, save adapter, migrations |
| `src/server/Remotes/` | request parsing, rate limiting, sanitized responses |
| `src/client/` | UI, input, animation, effects, and local presentation |
| `docs/prd/` | testable feature specifications |
| `memory-bank/` | current verified project state and backlog |
| `adr/` | architecture decisions |
| `ci/` | compile, test, lint, and freshness gates |

## Core transaction principle

Every valuable action follows one server-side flow:

```text
Validate → Lock/verify session → Read snapshot → Check preconditions
→ Build Atomic Write Set → Commit once → Emit events → Respond
```

Examples:

- Buying an egg deducts Gold and grants the egg in the same commit.
- Starting a hatch moves the egg into hatch state and stores the server finish time in the same
  commit.
- Claiming a hatch consumes the hatch state and grants exactly one dragon in the same commit.
- Collecting a nest advances the production cycle and grants the output in the same commit.
- Selling production output removes inventory and grants Gold in the same commit.

Clients never choose rewards, rarity, finish time, prices, sell values, or ownership.

## Data classification

### Persistent

Gold, owned eggs, dragons, food, hatch state, growth progress, production state, uncollected output,
display assignments, boosts, and pending claims.

### Runtime

Models, animations, current targets, temporary cooldowns, remote connections, dirty flags, caches,
and session-lock heartbeat state.

### Derived

Sell values, final hatch odds, production speed, quality bonuses, display synergy, and slot limits.
Derived data is recalculated from authoritative inputs and configuration.

## Getting started

1. Follow [`SETUP.md`](SETUP.md).
2. Read [`AGENTS.md`](AGENTS.md).
3. Open an agent session at the repository root.
4. Run:

```text
workflow: resume
```

5. Select the highest-priority item in `memory-bank/backlog.md`.
6. Implement with tests and finish only after the proof surface is green.

## Verification

```bash
ci/compile-check.sh
ci/run-tests.sh fast
ci/lint.sh
```

The machine-readable final JSON status is the source of truth. Do not claim a feature is complete
unless the required gates pass.

## Recommended first MVP slices

1. Profile schema, validation, and session lock.
2. Buy Egg transaction.
3. Start Hatch and Claim Hatch transactions.
4. Feed Dragon and growth calculation.
5. Assign Producer and Collect Nest transactions.
6. Sell Production Egg transaction.
7. Display assignment and one simple synergy bonus.
8. Save recovery, duplicate-request tests, and disconnect tests.

Advanced raids, trading, breeding, clans, and live events should remain outside the first MVP unless
the project owner explicitly changes scope.
