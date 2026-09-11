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

## Task 2.5: A report page with the analysis in it
The kit renders `report.html` (and `summary.html`) from `report.json`:
self-contained, no CDN, light and dark; win rates as bars with interval
whiskers, deltas as signed bars, sweeps as an inline SVG line with a
confidence band, standings as bars, the matrix as a heatmap. A `--render`
step re-emits the page with an `analysis.md` from the run directory
embedded at the top, so an agent can show a human the numbers and the
reading in one place.
- Acceptance: CI renders a matchup, a sweep-with-baseline and a tournament
  report and parses each with Godot's `XMLParser` (strict markup) and
  checks the expected sections; the human look is Checkpoint 2. RED today:
  no `report.html` exists and `--render` is an unknown flag.
- Files: `sim/sim_html.gd` (new), `sim_cli.gd`, `sim_report.gd`, `ci.yml`,
  skill and docs.
- Major: yes, a new artifact, a CLI flag and a new sim file.

## Task 2.6: Two procedural skills for a game's agent
`author-sim-suite` interviews grill-me style, one question at a time, and
never assumes the user remembers a field: what is the claim, what metric
moves if it is false, which form (matchup, sweep plus baseline,
tournament), which battle and AIs, how many runs for the interval to be
narrower than the effect; then writes the JSON, proves it can go RED, and
pins assertions. `run-sim-suite` runs one or all, reads summary then
report, writes `analysis.md`, renders and opens the page, and says where a
conclusion worth keeping goes (the suite description, a decision), since
run directories are transient.
- Acceptance: the install skill copies both; Checkpoint 2 uses only them.
  No automated proof: a skill is prose. RED today: the skills do not exist.
- Files: `.github/skills/author-sim-suite/`, `.github/skills/run-sim-suite/`,
  `symlink-config.txt`, install skill, `run-balance-sim` trimmed to the
  schema reference the two procedures point at.
- Major: no; follows the exported-skill pattern (`run-balance-sim`).

## Checkpoint 2 (HUMAN)
- [ ] Using only `author-sim-suite` and `run-sim-suite` in `example-game/`,
      ask one balance question (bump a unit stat), get the page, and read
      it. Did the interview ask everything it needed, and does the page
      tell you whether the change mattered without opening the JSON?
