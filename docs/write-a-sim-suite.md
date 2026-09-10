# Write a sim suite

A suite is a JSON file that names a battle, how many seeded runs to play per
matchup, which AIs play which faction, optionally one parameter to sweep, and
what must hold in the aggregates. The schema, override roots, metric paths
and reading guide are in `.github/skills/run-balance-sim/SKILL.md`.

## Example

```json
{
  "suite_id": "cavalry_is_not_dominant",
  "description": "Cavalry attack swept 5..8: at what value does the mirror stop being fair?",
  "battle": "res://battles/open_field.json",
  "runs": 100,
  "seed": 42,
  "matchups": [{"id": "mirror", "ai": {"red": "greedy", "blue": "greedy"}}],
  "sweep": {"path": "unit_defs.cavalry.attack", "values": [5, 6, 7, 8]},
  "assertions": [
    {"metric": "win_rate.red", "comparator": "lte", "expected": 0.7},
    {"metric": "metrics.def.cavalry.kills", "sweep_value": 8, "comparator": "lte", "expected": 3.0}
  ]
}
```

## Running

```powershell
./simulate.ps1                          # every suite under src/sim/suites
./simulate.ps1 -Suite cavalry_is_not_dominant -Runs 300
./simulate.ps1 -Suite cavalry_is_not_dominant -Runs 1 -Seed 57 -Trace
```

Or directly, from any project that has the addon; this is the whole test
runner, and what a game's CI runs on any platform:

```
godot --headless --path <project> --script res://addons/tactical_battle_kit/sim/sim_cli.gd -- \
  (--suite res://sim/suites/<name>.json | --suites res://sim/suites) \
  [--out res://artifacts/sim] [--runs N] [--seed S] [--trace] [--register res://path/to/ai_pack.gd]
```

`--suites` runs every `*.json` in the directory in name order, in one
process. Exit 0 pass, 1 assertion failure, 2 runtime error, the worst across
suites. Each suite prints a `RESULT` JSON line, an `ARTIFACTS` line, and one
`FAILED` line per failed assertion; `--suites` ends with a `SUMMARY` JSON
line. Trust the printed verdict over the process exit code: a missing
`SUMMARY` means the engine died mid-run, which is a failure too.

## Registering AIs

A battle's ruleset registers its own AIs through `ai_scripts()`. An AI that
is not part of the ruleset (an experimental opponent, a pack from another
module) is named by a script with a static `register()`:

```gdscript
extends RefCounted

static func register() -> void:
	AiRegistry.register("rush", RushAi)
```

Either the suite lists it, `"register": ["res://ai/raider_pack.gd"]`, or the
CLI gets `--register`. Registrations are process-wide, so a pack a suite
loads is visible to every suite after it in a `--suites` run.

## What comes out

`<out>/<suite_id>/<timestamp>/report.json` (everything, including each run's
seed, winner, reason and rounds), `report.md` (the tables), `trace.json` when
`--trace` was given (one run's full event log and final state), and
`latest.json` pointers per suite and overall. A `--suites` run also writes
`<out>/summary.json` and `summary.md`: one row per suite and the verdict.

## Sweeps

One dotted path, a list of values, one cell per value per matchup. Roots:
`unit_defs.<id>.<field>`, `terrain_defs.<id>.<field>`, `ruleset.<key>`
(through `configure`), `battle.<path>` (deep-merged onto the battle
dictionary, so army composition is sweepable too). Assertions without
`sweep_value` apply to every cell.

## Reading a sweep

The point of a sweep is the shape, not a pass. Read the matchup table across
values and look for the knee; assert loose guard rails (no draws, no
rejections, the metric moves in the expected direction at the extremes) and
let the table answer the question.
