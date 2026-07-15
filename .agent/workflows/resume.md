# workflow: resume

Step 1 of the L3 loop. Run at the start of every session, before picking a task.

1. Read the "always" memory set: `memory-bank/handoff.md`, `memory-bank/CONTEXT.md`,
   `memory-bank/activeContext.md`, `memory-bank/progress.md`, `memory-bank/backlog.md`.
2. Cross-check memory against the repo:
   - `git log -5 --oneline` and `git status` — does recent history match what `handoff.md` claims?
   - `ci/gate-freshness.sh` — is the last green proof surface still valid for this tree?
3. If memory and repo/tests disagree, the repo wins. Note the stale memory so it gets corrected
   during `end-session`, but do not silently trust it in the meantime.
4. Report back to the human/agent driving the session:
   - Current verified MVP capability (from `progress.md`, only claims backed by a green run).
   - Current save-schema version (from `memory-bank/systemPatterns.md` or the latest schema ADR).
   - Next backlog item (top of `memory-bank/backlog.md` unless told otherwise).
   - Any stale or conflicting memory found in step 3.
   - Whether the proof surface is FRESH or STALE per `ci/gate-freshness.sh`.
5. If STALE, run `ci/compile-check.sh` and `ci/run-tests.sh fast` before starting new work so the
   baseline is known-green.

Do not start implementation as part of this workflow — hand off to Plan (step 2 of the loop).
