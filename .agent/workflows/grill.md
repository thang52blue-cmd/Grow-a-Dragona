# workflow: grill

Front of the new-feature pipeline. Use before any non-trivial feature to reach alignment before
code is written.

1. Interview the human about the feature: goal, player-facing behavior, what's explicitly out of
   scope, and how it interacts with existing systems (check `memory-bank/systemPatterns.md` and the
   GDD in `Doc/` for conflicts).
2. Keep asking until ambiguity is resolved — do not assume; a wrong assumption here is expensive
   because everything downstream (`to-prd`, `to-issues`, implementation) inherits it.
3. Whenever a new shared term or concept is coined or clarified (e.g. a mechanic name, a data field's
   meaning), mint it into `memory-bank/CONTEXT.md` so later sessions decode it the same way.
4. If the conversation settles a decision with lasting consequences (architecture, schema, scope
   cut), log it as a dated entry in `memory-bank/decisionLog.md` and write the ADR under `adr/`.
5. Stop when the human confirms alignment. Hand off to `workflow: to-prd`.

Do not skip this for tiny, already-clear tasks — go straight to the normal loop instead.
