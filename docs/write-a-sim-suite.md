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
CLI gets `--register`. The CLI resets the registry before each suite, so a
pack a suite loads is visible to that suite alone; a `--register` pack is
visible to every suite in the run.

## What comes out

`<out>/<suite_id>/<timestamp>/report.json` (everything, including each run's
seed, winner, reason and rounds), `report.md` (the tables), `report.html`
(the same, as a self-contained page: bars with interval whiskers, delta
bars, a sweep chart, standings and matrix), `trace.json` when `--trace` was
given (one run's full event log and final state), and `latest.json`
pointers per suite and overall. A `--suites` run also writes
`<out>/summary.json`, `summary.md` and `summary.html`: one row per suite
and the verdict. Every `ARTIFACTS` line is followed by a `URL` line, the
`file:///` address of that page.

## Showing someone the answer

Write `analysis.md` in the run directory (headings, paragraphs, bullets,
bold and code are rendered; nothing else is interpreted), then re-render:

```
godot --headless --path <project> --script res://addons/tactical_battle_kit/sim/sim_cli.gd -- \
  --render res://artifacts/sim/<suite_id>/<timestamp>
```

It prints `RENDERED <path>` and `URL file:///...`; the page opens with the
analysis at the top. Run directories are transient artifacts, so a
conclusion worth keeping goes into the suite's `description` and
assertions, or a decision record; the page is for showing someone today.

## Tournaments

Which AI is best, across maps and whichever side moves first: replace
`battle` and `matchups` with a `tournament` block.

```json
{
  "suite_id": "ai_tournament",
  "runs": 30,
  "seed": 400,
  "register": ["res://ai/raider_pack.gd"],
  "tournament": {
    "ais": ["random", "garrison", "rush"],
    "battles": ["res://battles/outpost.json"],
    "swap_sides": true
  },
  "assertions": [
    {"metric": "matrix.garrison.random", "comparator": "gte", "expected": 0.6},
    {"metric": "standings.rush.games", "comparator": "eq", "expected": 120}
  ]
}
```

Every pair of AIs plays every listed battle, the first AI on the battle's
first declared faction and the second on the second; `swap_sides` adds the
reverse cell. Battles must have exactly two factions and are expected to
share a ruleset the AIs understand. No mirror cells (a self-match says
nothing about a ranking) and no duplicate ids: a variant of an AI is
registered under its own id and listed as one. The report leads with a
standings table sorted by points and a matrix of who beats whom, then the
per-cell table. Assertions on `standings.<ai>.<field>` and `matrix.<a>.<b>`
resolve against those tables; everything else resolves per cell as usual,
and cells are named `<battle_id>:<first>_vs_<second>`.

The standings are the answer; keep the assertions to what must hold for the
table to mean anything (a known-bad AI stays at the bottom, nothing is
rejected, every AI played the expected number of games). The example game's
tournament found its experimental AI beating its shipped one, which is what
the table is for.

## Sweeps

One dotted path, a list of values, one cell per value per matchup. Roots:
`unit_defs.<id>.<field>`, `terrain_defs.<id>.<field>`, `ruleset.<key>`
(through `configure`), `battle.<path>` (deep-merged onto the battle
dictionary, so army composition is sweepable too). Assertions without
`sweep_value` apply to every cell.

## Baselines and intervals

Every rate and mean in a report carries a 95% interval (`62% ±9` in the
tables, `ci95.<path>` in the JSON and in assertions). To make a stat change
reviewable rather than eyeballed, name the current build as the baseline
and assert on deltas:

```json
{
  "suite_id": "raider_attack_baseline",
  "battle": "res://battles/outpost.json",
  "runs": 60,
  "seed": 500,
  "matchups": [{"id": "garrison_vs_rush", "ai": {"garrison": "garrison", "raiders": "rush"}}],
  "sweep": {"path": "unit_defs.raider.attack", "values": [5, 6, 7]},
  "baseline": {"sweep_value": 5},
  "assertions": [
    {"metric": "ci95.win_rate.garrison", "comparator": "lte", "expected": 0.15},
    {"metric": "mean_rounds", "within": 3, "of": "baseline"}
  ]
}
```

`baseline` is `{sweep_value}` (each matchup compared to itself at that
value), `{matchup}` (each sweep value compared to that matchup), or both
(one fixed cell). Non-baseline cells get a `delta` tree with the same paths
as the aggregate, a "Deltas vs baseline" table in the report, and a
"vs baseline" line per cell for the custom and faction metrics. A `within`
assertion passes when |delta| is at most `x`; it applies to non-baseline
cells only and needs `of: "baseline"`.

Read the delta against the intervals beside it: the example above found
one attack point takes the garrison from 68% ±11 to 3% ±5, a breakpoint,
while the pace of the fight barely moved. At 30 runs a win rate is about
±17 points; at 120 about ±9. Raise `runs` until the interval is narrower
than the effect you are looking for, not until the assertion passes.

## Reading a sweep

The point of a sweep is the shape, not a pass. Read the matchup table across
values and look for the knee; assert loose guard rails (no draws, no
rejections, the metric moves in the expected direction at the extremes) and
let the table answer the question.
