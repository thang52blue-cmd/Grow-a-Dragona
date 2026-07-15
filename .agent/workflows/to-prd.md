# workflow: to-prd

Second step of the new-feature pipeline. Run after `workflow: grill` has produced alignment.

1. Synthesize the grill conversation (and any linked `memory-bank/CONTEXT.md` terms) into a single
   PRD file at `docs/prd/<slug>.md`, where `<slug>` is a short kebab-case name for the feature.
2. The PRD must include:
   - A one-paragraph summary of the feature and why it's in scope now.
   - Player-facing behavior, described concretely enough to disagree with.
   - Testable acceptance criteria — each one phrased so a test can pass or fail against it.
   - Explicit non-goals / out-of-scope items called out during grilling.
   - Data classification impact (persistent / runtime / derived) if the feature touches save state.
3. Do not invent acceptance criteria that weren't discussed — if something is unresolved, list it as
   an open question instead of guessing.
4. Hand off to `workflow: to-issues` once the PRD is written.
