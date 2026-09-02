# /test

Unplanned verification work: reproduce a bug, or backfill missing coverage.

- Two proof artifacts, never a unit test (D1). Rules, AI, determinism and
  balance claims get a sim suite under `src/sim/suites/` (headless, runs in
  CI). Anything a screenshot can catch, the view, the runner, and input
  bridging get an in-engine scenario under `src/validation/scenarios/`.
- Bug fixing is reproduce-first: log it in bugs.md (`B-<n>`), write the
  suite or scenario that fails the way the bug fails, then fix. The proof is
  the regression guard; the bugs.md entry closes with one line pointing at it.
- A determinism bug gets a sim assertion on the exact seed: `--runs 1 --seed
  <n> --trace` and assert on the trace, not on averages.
- Backfilled coverage still proves RED: neuter the behavior temporarily and
  watch the proof fail before trusting it.
- A fixed bug with no proof is a coverage gap, not tidying (bugs.md rules).
