# Phase 2: The sim as a test framework for consuming games
**Goal:** A game that consumes the addon drops suite files next to its own
ruleset, AIs and battles, runs one command, and gets pass/fail plus reports;
the kit owns discovery, runs, measurement and reporting, like a unit-test
framework. Then the measurements get sharper: tournaments across AIs and
maps, and deltas with confidence intervals against a baseline. Items from
docs/balance-validation-proposal.md not here wait in todo.md.

## Task 2.1: An example game that proves the harness from outside
A minimal Godot project in this repo (`example-game/`: its own ruleset, one
bespoke AI, one battle, two suites) links the addon the way the install
skill says and runs its suites in CI. It is both the fixture and the only
demonstration of a consuming project's layout, so everything checked into
it is what a real game would write; the install skill points at it as the
finished result of its steps.
- Acceptance: CI job `example-game` runs its suites; `own_ai_beats_random`
  asserts `win_rate.<faction> gte 0.8` for the bespoke AI, so a kit change
  that breaks registration or the loader goes RED there, not in a kit
  example. RED today: the job and the project do not exist.
- Files: `example-game/` (new, a second Godot project), `symlink-config.txt`,
  `.github/workflows/ci.yml`, install doc and skill.
- Major: yes, a new top-level directory and a CI contract.

## Task 2.2: One command runs every suite, from any project
`sim_cli.gd` gains `--suites <dir>`: discover `*.json`, run each, print one
`RESULT` line per suite and a final `SUMMARY` line, write
`artifacts/sim/summary.md` (one row per suite, worst exit code). A suite may
name `register: [script paths]` so an AI pack outside the ruleset's
`ai_scripts()` loads without CLI flags. `simulate.ps1` and the CI bash loop
shrink to wrappers; the example game uses the raw command.
- Acceptance: the example game's CI step is one godot command. The failure
  path is proven with a throwaway suite CI writes into the project, runs
  expecting exit 1, and deletes, so every checked-in suite passes. RED
  today: `--suites` is unknown and the CLI exits 2.
- Files: `sim/sim_cli.gd`, `sim/sim_report.gd` (summary), `sim_suite.gd`
  (`register`), `simulate.ps1`, `ci.yml`, run-balance-sim skill, docs.
- Major: yes, CLI and suite JSON gain fields.

## Task 2.3: Tournament block
`tournament: {ais, battles, swap_sides}` replaces `battle` + `matchups` and
expands to every ordered AI pair on every battle (one ruleset). Report gains
`standings.<ai>.{win_rate, points, games}` and a pairwise matrix. No Elo: a
full round-robin on paired seeds already orders the AIs.
- Acceptance: `skirmish_tournament` with `[random, greedy]` on open_field
  and a new chokepoint battle, swap on; asserts `standings.greedy.win_rate
  gte 0.9` and `standings.random.games eq 4`. RED today: null metric.
- Files: `sim_suite.gd`, `sim_report.gd`, skirmish `battles/`, skill, docs.
- Major: yes, a suite root and a report section.

## Task 2.4: Baseline, deltas and confidence intervals
A suite names one cell `baseline`. Every aggregate leaf gets a `ci95`
half-width (Wilson for rates, normal for means; aggregation keeps sum of
squares), non-baseline cells get `delta`, and assertions accept
`{"metric", "within": x, "of": "baseline"}`.
- Acceptance: `skirmish_cavalry_baseline` sweeps cavalry attack with the
  shipped value as baseline; asserts `ci95.win_rate.red lte 0.12` at 120
  runs and `mean_rounds within 4 of baseline` at attack+1. RED today:
  `ci95` is null and `within` has no comparator.
- Files: `sim_suite.gd`, `sim_report.gd`, skill, docs; the example game
  gains one baseline suite so the feature is proven from outside too.
- Major: yes, aggregate and assertion shapes.

## Checkpoint 2 (HUMAN)
- [ ] Following only the install skill, add a third suite to `example-game/`
      that bumps one of its unit stats and read the delta/CI table. Did the
      kit tell you whether the change mattered, with no step you had to
      guess?
