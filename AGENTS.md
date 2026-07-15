# AGENTS.md
> Source of truth for AI agents in this repo. Keep this file under ~150 lines. Prefer rules enforced
> by tests, lint, hooks, or CI over repeated prose.
## Project
**Grow-a-Dragona** is a Roblox creature-raising and economy game built code-first with Rojo.
```text
Buy Egg → Hatch → Feed Baby Dragon → Adult Dragon
→ Production/Display → Collect → Sell → Buy Better Egg
```
The server owns all valuable state. Clients request actions and render approved results.
References: `memory-bank/projectbrief.md`, `memory-bank/systemPatterns.md`,
`memory-bank/backlog.md`, `docs/prd/`, and `adr/`.
## MVP scope
Build only:
- Gold, food, basic egg purchasing, timed hatching, dragon ownership, growth, and favorite state.
- Production assignment, nest collection, selling, display assignment, and simple derived synergy.
- Save/load, schema validation, session locking, idempotent transactions, and basic anti-cheat.
- Tests for pure domain logic and atomic economy/progression mutations.
Defer trading, breeding, clans, live events, complex raids, cross-server markets, and advanced
monetization until the core loop is verified.
## Agent workflow
When the user says `workflow: <name>`, read `.agent/workflows/<name>.md` first and follow it exactly.
Workflow files define behavior; memory records project state. Repo state and tests override memory.
1. **Resume** — load `handoff.md`, `CONTEXT.md`, `activeContext.md`, `progress.md`, `backlog.md`;
   compare them with git and tests.
2. **Plan** — choose the top backlog item unless told otherwise; use at most five bullets.
3. **Specify** — update a testable spec before non-trivial implementation.
4. **Execute** — stay inside allowed paths and the selected task.
5. **Verify** — run compile and fast tests.
6. **Write back** — record verified state only; separate done, in progress, and planned.
New features use:
```text
grill → to-prd → to-issues → backlog → resume → tdd → verify → diagnose? → end-session
```
Skip alignment only for tiny, already-clear changes.
## Data classification
**Persistent:** Gold, gems, owned dragons/eggs, food, hatch state, growth, production assignments,
cycle state, uncollected output, display assignments, boosts, and pending claims.
**Runtime-only:** models, animation/follow/target state, temporary cooldowns, connections, caches,
dirty flags, and session-lock heartbeat.
**Derived:** sell value, hatch odds, production speed, quality bonus, display synergy, and slot
limits. Recalculate derived values from authoritative inputs and config; do not save them when they
can be deterministically recomputed.
## Transaction model
Every economy or progression action is a server-side transaction:
```text
Validate request
→ verify session lock
→ read current snapshot
→ check ownership, balance, state, cooldown, and idempotency
→ build one Atomic Write Set
→ commit once
→ emit post-commit events
→ return sanitized result
```
Expected modules:
```text
src/server/Transactions/
├── Economy/BuyEggTransaction.luau
├── Economy/SellProductionEggTransaction.luau
├── Hatching/StartHatchTransaction.luau
├── Hatching/ClaimHatchTransaction.luau
├── Dragon/FeedDragonTransaction.luau
├── Dragon/SetFavoriteTransaction.luau
├── Production/AssignProducerTransaction.luau
├── Production/CollectNestTransaction.luau
├── Display/AssignDisplayTransaction.luau
└── Display/RemoveDisplayTransaction.luau
```
A transaction may mutate multiple fields, but they must commit as one logical unit. Never deduct
currency in one save and grant the item in another.
## Security rules
- Never trust client currency, rewards, rarity, timestamps, ownership, prices, or calculated values.
- Remote payloads contain stable identifiers, request ID, and intent only.
- Validate type, range, ownership, state transition, rate limit, and duplicate request ID.
- Use server timestamps for hatch, production, cooldown, and boost calculations.
- Reject stale, duplicated, impossible, or out-of-order requests.
- Grant rewards only after a successful commit.
- Post-commit UI/effect events cannot mutate persistent state.
- Disconnect is not rollback; recovery comes from atomic commits, idempotency, and persisted state.
- Return only the profile fields required by the client UI.
## Hard rules
- No unverified “done”; compile and fast tests must be green.
- Repo state wins over memory.
- Put prices, timings, odds, growth costs, rates, and bonuses in `src/shared/Data/*.json`.
- Pure growth, reward, and transaction rules live in `src/shared/` without engine globals or IO.
- Keep remotes, DataStore adapters, models, and effects as thin engine glue.
- Do not edit human-owned foundation scope files without explicit instruction.
- Decision logs are append-only.
- Public save-schema and transaction-contract changes require explicit approval and an ADR.
## Allowed paths
Agents may create or edit `src/**`, `tests/**`, `docs/**`, `adr/**`, `ci/**`, `.agent/**`, and
`memory-bank/**` except human-owned foundation files.
## Gated actions
Stop and ask before:
- destructive/history-rewriting git operations or bulk deletion of production code;
- editing `default.project.json`, dependencies, toolchain pins, or language-mode configuration;
- publishing, deploying, uploading places, or calling Roblox web APIs;
- reading or writing secrets, cookies, API keys, or `.env`;
- changing live save schemas, public transaction contracts, or running player-data migrations.
## Verification
```bash
ci/gate-freshness.sh
ci/compile-check.sh
ci/run-tests.sh fast
ci/run-tests.sh engine
ci/lint.sh
```
The final machine-readable JSON status is ground truth. Any undocumented non-green status blocks
completion.
## Coding conventions
- Strict Luau; one public module per file; file name matches module name.
- Colocate specs as `<Module>.spec.luau` unless the test harness says otherwise.
- `src/shared/` must not access DataStoreService, RemoteEvent, Instances, or engine IO.
- Use typed domain records and transaction results; avoid mutable shared transaction tables.
- Use `task.*` deliberately; no Promise library without an ADR.
- No committed `print()` calls; use the project logger.
- Emit analytics only after successful commits.
## Memory map
| File | Purpose | Load |
|---|---|---|
| `handoff.md` | last verified session state | always, first |
| `CONTEXT.md` | shared vocabulary | always |
| `activeContext.md` | current focus and next task | always |
| `progress.md` | verified capabilities and issues | always |
| `backlog.md` | priorities and definitions of done | always |
| `systemPatterns.md` | architecture and contracts | on demand |
| `decisionLog.md` | append-only ADR index | on demand |
| `techContext.md` | commands and environment | on demand |
| `projectbrief.md` | MVP scope | scope work |
| `productContext.md` | player experience and rationale | scope work |
