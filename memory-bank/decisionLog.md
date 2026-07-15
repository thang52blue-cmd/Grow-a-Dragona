# Decision Log

> On-demand load. Append-only index. Full ADRs live under `adr/`, one file each. Never rewrite a
> past entry — supersede it with a new dated one.

- 2026-07-14 — **ADR-001: Initial toolchain and project structure.** Pinned rojo 7.7.0, lune 0.10.5,
  selene 0.31.0, stylua 2.5.2, luau-lsp 1.68.1 in `rokit.toml`; established the `src/shared` /
  `src/server` / `src/client` Rojo tree. See `adr/ADR-001-initial-toolchain-and-structure.md`.
