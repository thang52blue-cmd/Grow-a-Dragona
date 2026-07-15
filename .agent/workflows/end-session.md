# workflow: end-session

Step 5 of the L3 loop. Run before handing off or ending a session.

1. Verify before writing anything: run `ci/compile-check.sh` and `ci/run-tests.sh fast`. Read the
   JSON `status` field. If it is not `PASSED` (or `COMPILE_OK`), do not record the task as done —
   record it as in-progress with the actual blocking status.
2. Update memory with VERIFIED state only:
   - `memory-bank/activeContext.md` — current focus, last 3 completed items, current + next task.
   - `memory-bank/progress.md` — move the item to "what works" only if tests are green; otherwise
     keep it under "what's left" or "known bugs".
   - `memory-bank/backlog.md` — check off finished items, re-prioritize if scope changed.
   - `memory-bank/handoff.md` — overwrite with this session's state transfer (this is what the next
     `resume` reads first).
3. If a decision was made that changes architecture, schema, or a public contract, append a new
   dated entry to `memory-bank/decisionLog.md` (append-only — never edit past entries) and write the
   full ADR under `adr/`.
4. If both gates in step 1 were green and the working tree reflects that state, stamp freshness:
   `ci/gate-freshness.sh --stamp`.
5. Run `ci/lint.sh` (advisory). Fix issues when practical; do not block the session on it.

Never write "done" to memory for a task whose tests are missing, red, skipped, or stale.
