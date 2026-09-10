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
- [ ] Task 2.4: baseline cell, deltas, ci95, `within ... of baseline`
- [ ] Checkpoint 2: add a stat-bump suite to `example-game/` from the skill alone

## Unplayed, carried

- [ ] Checkpoint 1: Play a breach game as the squad on the live build. Does
      the cover readout make hits and misses feel fair, and is the AI's
      overwatch legible enough that walking into it reads as your mistake?

## Follow-ups

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
