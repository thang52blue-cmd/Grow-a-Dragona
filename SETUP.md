# SETUP — Grow-a-Dragona first run

Target: from a new machine to a green local compile and fast-test gate.

Windows, macOS, and Linux are supported. On Windows, run `ci/*.sh` from Git Bash or the shell used
by the agent harness.

## 1. Install the toolchain

Install Rokit, then run from the repository root:

```bash
rokit install
```

This installs the versions pinned by the repository.

If a pin is no longer available, do not silently change it. Updating `rokit.toml` is a gated,
human-approved action because it changes the toolchain used by every contributor and CI run.

## 2. Verify the local proof surface

```bash
ci/compile-check.sh
ci/run-tests.sh fast
```

Expected green statuses are documented by the scripts. Read the final machine-readable JSON line,
not only the shell exit code.

Run the advisory formatting and lint pass:

```bash
ci/lint.sh
```

## 3. Connect Rojo for visual testing

Install the Rojo Studio plugin, then run:

```bash
rojo serve
```

Connect Roblox Studio to the local Rojo server.

Studio is used to inspect models, UI, animations, remotes, and multiplayer behavior. Source code in
the repository remains the source of truth.

Do not publish or upload the place from an autonomous agent session. Deployment is gated.

## 4. Start the first agent session

Open the agent at the repository root and say:

```text
workflow: resume
```

The agent should read the hot memory set, compare it with git and tests, and report:

- current verified MVP capability;
- current save-schema version;
- next backlog item;
- stale or conflicting memory;
- whether the proof surface is fresh.

## 5. Recommended first technical validation

Before implementing a large feature, prove these Grow-a-Dragona foundations:

1. A pure-Luau test can validate a transaction without Roblox engine globals.
2. Buying an egg cannot deduct Gold without granting the egg.
3. A duplicate request ID cannot grant the same egg or dragon twice.
4. Hatch and production timers use server timestamps.
5. A stale or missing session lock blocks valuable mutations.
6. Derived values are recalculated rather than trusted from saved or client data.
7. Invalid ownership, impossible state transitions, and forged values are rejected.

## 6. Local development workflow

For a normal task:

```text
workflow: resume
→ update or write the spec
→ implement with TDD
→ run compile and fast tests
→ inspect in Studio when engine behavior is involved
→ workflow: end-session
```

For a new non-trivial feature:

```text
workflow: grill
→ workflow: to-prd
→ workflow: to-issues
→ normal implementation loop
```

## 7. Important local rules

- Do not edit prices, timings, odds, growth costs, or production values directly in logic.
- Do not test valuable state by invoking client code as authority.
- Do not use live DataStores for normal unit tests.
- Do not store secrets, Roblox cookies, or API keys in the repository.
- Do not change save schema or run migrations without an explicit ADR and human approval.
- Do not mark a task complete when tests are missing, red, skipped, or stale.

## 8. Optional editor setup

Recommended VS Code extensions:

- Luau language server.
- StyLua.
- Selene.
- Rojo.

The repository configuration should be used as-is. A quiet language-mode or analyzer change can
weaken the compile gate and therefore requires approval.
