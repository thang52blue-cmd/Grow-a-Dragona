# ADR-001: Initial toolchain and project structure

## Status

Accepted — 2026-07-14

## Context

The repo contained only docs (README, SETUP, AGENTS/CLAUDE.md, the GDD) and no Rojo project, no
toolchain pins, and no `src/`. AGENTS.md already describes a target architecture (transaction model,
folder layout, verification commands) that depends on these existing. The user asked to create the
basic project structure.

## Decision

- Rojo tree (`default.project.json`): `src/shared` → `ReplicatedStorage.Shared`, `src/server` →
  `ServerScriptService.Server`, `src/client` → `StarterPlayer.StarterPlayerScripts.Client`.
- Toolchain pinned in `rokit.toml`, versions confirmed against each project's GitHub Releases API on
  2026-07-14: rojo 7.7.0, lune 0.10.5, selene 0.31.0, stylua 2.5.2, luau-lsp 1.68.1 (added beyond the
  four AGENTS.md names, to give `ci/compile-check.sh` a strict-mode analyze binary).
- `.luaurc` sets `languageMode: "strict"` with linting on, matching AGENTS.md's "strict Luau
  everywhere" rule.
- `wally.toml` created with no dependencies yet — a placeholder until a package is actually needed.
- `src/server/Transactions/**` and `src/server/Persistence/`, `src/server/Remotes/`,
  `src/shared/Domain/`, `src/shared/Data/`, `src/client/` were created as empty directories (tracked
  via `.gitkeep`), not pre-filled with stub modules — implementations land with their backlog item
  and tests (AGENTS.md "test-first for logic"; avoids half-finished stand-in code).
- `src/shared/Types/Types.luau` was populated with `Element`/`Rarity`/`EggVariant` type exports since
  these are fixed vocabulary from the GDD, not tunable data or feature logic.
- `ci/*.sh` scripts implement the JSON-status contract from AGENTS.md. They were smoke-tested in this
  environment only against the *absence* of the pinned toolchain (confirming they fail loudly rather
  than falsely reporting green) — not yet run against a real install.

## Consequences

- `rojo serve` and Studio connection become possible once `rokit install` runs on a machine with the
  real toolchain — not yet verified in this session's environment.
- `ci/compile-check.sh`'s `luau-lsp analyze` step has no Roblox global type definitions wired in;
  it will need one once `src/server/`/`src/client/` code touches engine globals. Tracked in
  `memory-bank/techContext.md`, not yet its own backlog item.
- Backlog item #3 (`memory-bank/backlog.md`) is reserved for the engine-lane activation ADR that
  AGENTS.md's gated-actions section already refers to by that number.
