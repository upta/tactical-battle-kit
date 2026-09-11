# Todo

Phase 2 in flight: tasks/phase-2.md (the sim as a test framework for
consuming games). Every task is major; each goes through the
architecture-proposal gate at /build.

- [x] Task 2.1: `example-game/`, fixture and layout example, run in CI
      ✅ 2026-09-10 (two suites green from the foreign root; CI job `example-game`; simulate.ps1 now imports every run)
- [x] Task 2.2: `--suites <dir>`, SUMMARY line, suite-level `register`
      ✅ 2026-09-10 (one command per project; failure path proven in CI with a throwaway suite; rush AI registered from a pack)
- [x] Task 2.3: tournament block, standings and pairwise matrix
      ✅ 2026-09-10 (round-robin over AIs × battles with side swap; found rush beats garrison 77% in the example game)
- [x] Task 2.4: baseline cell, deltas, ci95, `within ... of baseline`
      ✅ 2026-09-10 (Wilson and normal intervals on every aggregate; deltas table; one raider attack point flips the outpost 68% to 3%)
- [x] Task 2.5: `report.html` and `summary.html`, `--render` with `analysis.md`
      ✅ 2026-09-11 (self-contained pages with whiskers, delta bars, sweep chart, heatmap; check_reports.gd in simulate.ps1 and CI)
- [x] Task 2.6: `author-sim-suite` (grill-me interview) and `run-sim-suite` skills
      ✅ 2026-09-11 (one question per turn, never assumes a field; run skill ends with the page URL)
- [ ] Checkpoint 2: ask one balance question of `example-game/` using only the two skills; read the page

## Unplayed, carried

- [ ] Checkpoint 1: Play a breach game as the squad on the live build. Does
      the cover readout make hits and misses feel fair, and is the AI's
      overwatch legible enough that walking into it reads as your mistake?

## Follow-ups

- [ ] `skirmish_mirror_is_fair` passes by seed: red reads 31% ±8 at its own
      seed and 20% ±7 at seed 5000 (cavalry baseline suite), so the 25%
      floor is not supported by the numbers. Its description calls below
      25% a rule problem; decide whether the first-mover penalty is the rule
      or the greedy AI, then move the floor or fix the cause.
- [ ] `rush_raiders_vs_garrison` reads 75% at seed 300 and 47% at seed 400
      with ±15 intervals; its 0.5 floor holds only by seed. Raise runs or
      loosen the claim.
- [ ] Example game: the shipped garrison AI loses to the experimental rush
      AI 77% of the time and never wins as the attacker (ai_tournament).
      Decide whether the example should ship the better AI or keep the gap
      as the thing the tournament table shows.
- [ ] Grid sweeps (proposal item 3): `sweep` as a list, cross-product cells,
      one report table per secondary axis. SPEC lists it as open.
- [ ] Per-def usage metrics (proposal item 6): needs an `action_applied`
      kit event so game-specific kinds are counted; then delete
      `docs/balance-validation-proposal.md`.
- [ ] Balance search CLI (proposal item 4): bisect one override path with
      paired seeds until a metric lands within tolerance of a target. Needs
      2.4's tolerance semantics first.
- [ ] Parallel suites (proposal item 5): worker processes behind
      `--suites`, verdicts still from the `RESULT` line (D11).
- [ ] A fifth example with a charge-time scheduler, height as a grid layer,
      an oriented area pattern and a 2x2 footprint (FFT-style "plateau")
      would exercise the last seams no example touches.
- [ ] Frontier: the attacker AI still mostly draws against random play once
      it starves (`frontier_ai_beats_random`); decide whether that is the
      AI, the map, or the supply numbers, then tighten the assertion.
- [ ] Chess: castling and en passant are omitted; add them if chess is ever
      more than a seam demonstration.
- [ ] Godot on Linux logs "resources still in use at exit" after the compile
      walk (23 at the time of writing). Find the holder if the count grows.
