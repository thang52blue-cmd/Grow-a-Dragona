# workflow: to-issues

Third step of the new-feature pipeline. Run after `workflow: to-prd` has produced a PRD.

1. Slice the PRD at `docs/prd/<slug>.md` vertically — each slice should be independently shippable
   and testable, not a horizontal layer (e.g. "server transaction" is not a slice on its own; "Buy
   Egg end-to-end" is).
2. For each slice, add an item to `memory-bank/backlog.md` with:
   - A short title matching the PRD language.
   - A definition of done that names the specific test(s) that must go green — never a vague "works".
   - Any ordering dependency on other backlog items.
3. Preserve existing backlog priority ordering unless the human explicitly reprioritizes; append new
   items where they make sense in the sequence, don't just tack them at the bottom by default.
4. Once issues are filed, the normal loop takes over: `resume` → implement with TDD → verify →
   `diagnose` if red → `end-session`.
