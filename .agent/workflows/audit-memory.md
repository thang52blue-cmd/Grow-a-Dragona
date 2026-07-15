# workflow: audit-memory

Hygiene pass. Run periodically (~every 2 weeks) or whenever memory feels off — contradicts the repo,
references removed files, or has grown too large to load efficiently.

1. Re-read the "always" memory set and every "on demand" file at least once.
2. For each claim in memory, check it against the repo: does the referenced file/function/module
   still exist? Does `progress.md` claim something as done that `ci/run-tests.sh fast` cannot prove?
3. Correct or remove stale entries. `decisionLog.md` stays append-only — supersede old entries with a
   new dated one rather than rewriting history.
4. Trim duplication: if two files say the same thing, keep it in the one the memory map designates
   and point the other at it instead of repeating it.
5. Do not touch `memory-bank/projectbrief.md` or `memory-bank/productContext.md` during this pass —
   those require explicit human instruction to change.
6. Report what was corrected and why, so the human can sanity-check the audit itself.
