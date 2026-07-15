# CLAUDE.md

@AGENTS.md

The line above imports the cross-tool source of truth for **Grow-a-Dragona**. Read `AGENTS.md`
before doing any work.

## Claude-specific notes

- Project skills live in `.claude/skills/`.
- Standard implementation flow: `/resume` → `/tdd` → `/roblox-verify` → `/end-session`.
- Feature alignment flow: `/grill` → `/to-prd` → `/to-issues`.
- Use `/diagnose` when compile or tests are red.
- Use the `verifier` or `code-reviewer` subagents for noisy scans and large test logs.
- Hooks in `.claude/hooks/` enforce gated actions. Never bypass a blocked action.
- Prefer `/roblox-verify` over manually pasting long CI output.
- Treat all client requests as untrusted. Valuable Grow-a-Dragona mutations must pass through a
  server transaction and one Atomic Write Set.

Keep this file short. Product rules, save schema, transaction contracts, and verified project state
belong in `AGENTS.md`, `memory-bank/`, `docs/`, and `adr/`.
