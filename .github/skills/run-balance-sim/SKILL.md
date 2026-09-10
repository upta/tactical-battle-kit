---
name: run-balance-sim
description: Use when writing or reading a headless balance suite. Suite JSON schema, override and sweep roots, the metric paths assertions can target, how to read report.md, and how to replay one seed with a trace.
---

# Balance sim

A suite runs one battle N times per matchup with seeded AIs, optionally
swept across values of one override path, and asserts on the aggregates.
Runs headless, no window, in CI. Runner: `./simulate.ps1 [-Suite id] [-Runs n]
[-Seed s] [-Trace] [-ProjectPath dir]`, a thin wrapper over the engine entry
point `sim_cli.gd --suites <dir>`, which discovers, runs, prints a `RESULT`
line per suite and a `SUMMARY` line, and writes `<out>/summary.md` (its
header has the raw command; any CI runs that one line).

## Suite schema (`src/sim/suites/<suite_id>.json`)

| Field | Meaning |
| --- | --- |
| `suite_id` | Stable id; names the artifact folder |
| `description` | The question this suite answers, in one sentence |
| `battle` | Path to a battle JSON, or an inline battle dictionary |
| `runs`, `seed` | Runs per cell (default 100) and base seed (default 1); run i uses `seed + i` |
| `overrides` | Applied to every cell; roots below |
| `register` | Script paths with a static `register()` that puts AIs into `AiRegistry`; for an AI the ruleset's `ai_scripts()` does not ship |
| `matchups` | `[{id, ai: {faction: ai_id}}]`; omitted factions use the battle file's AI, else `random` |
| `sweep` | `{path, values}`; one cell per value per matchup |
| `tournament` | `{ais: [id...], battles: [path or dict...], swap_sides}`; replaces `battle` and `matchups` (and excludes `sweep`): every AI pair on every two-faction battle, reversed when `swap_sides`, no mirrors, no duplicate ids |
| `baseline` | `{sweep_value: v}` and/or `{matchup: id}`: the cell every other cell is compared to (same matchup at that value, that matchup at the same value, or the one fixed cell). Non-baseline cells gain a `delta` tree |
| `assertions` (relative) | `{metric, within: x, of: "baseline", matchup?, sweep_value?}`: passes when the cell's delta from its baseline is within ±x; needs `baseline` |
| `assertions` | `[{metric, comparator, expected, matchup?, sweep_value?}]` |

Override and sweep roots, all dotted paths:

- `unit_defs.<def id>.<exported property>` (subclass fields included)
- `terrain_defs.<def id>.<exported property>`
- `ruleset.<key>`: lands in the ruleset's `configure(params)`
- `battle.<json path>`: deep-merged onto the battle dictionary (`battle.units`
  replaces the whole list; `battle.custom.supply.regular` patches one value)

`overrides` is a nested object: `{"ruleset": {"heal_range": 0}}`. Dotted
keys are accepted too (`{"ruleset.heal_range": 0}`) and expanded; a root
that is not one of the four above is a warning in the log, never silent.

Proving RED without touching the rule: a temporary suite with an `overrides`
block that disables the mechanic (`{"ruleset": {"heal_range": 0}}`), run
with `-Suite <id>`, then deleted along with its `artifacts/sim/<id>/`.

Comparators: `eq neq gt gte lt lte`. A metric leaf missing from an existing
table reads as 0 (no run ended by that reason); a missing table fails.

## Metric paths (per matchup cell)

`win_rate.<faction>` · `draw_rate` · `mean_rounds` · `min_rounds` ·
`max_rounds` · `mean_decisions` · `reason.<reason>` ·
`metrics.faction.<f>.{damage_dealt,damage_taken,kills,deaths,healed,survivors,hp_share,first_blood}` ·
`metrics.faction.<f>.left_field.<status>` ·
`metrics.def.<def id>.{damage_dealt,damage_taken,kills,deaths}` ·
`metrics.events.<event type>` · `custom.<whatever summarize() returned>`.

Kit metrics are folded from the event log by `BattleSimulator.fold_metrics`;
`custom` is the ruleset's `summarize(state)`, numeric leaves only, averaged.

`ci95.<any path above except min/max_rounds>` is the 95% half-width of that
number: Wilson for rates (not zero at 0% or 100%), 1.96 standard errors for
means. Reports print rates as `62% ±9`. A delta smaller than the intervals
beside it is noise; at 30 runs a win rate is about ±17, at 120 about ±9.

In a tournament, two more resolve once against the folded tables, not per
cell: `standings.<ai>.{games,wins,draws,losses,win_rate,points}` (points =
wins + draws / 2) and `matrix.<a>.<b>` (a's win rate over every game a and b
played, both sides and all battles pooled). Cells are named
`<battle_id>:<first>_vs_<second>`, so a per-cell assertion can still pick
one with `matchup`. Run i of every cell uses the same seed, so a swapped
pair differs only in who moved first.

## Writing a suite that has teeth

- Name the metric that would move if the claim were false, and assert that.
  `metrics.events.rejected eq 0` proves the AI never returned an illegal
  action; it says nothing about whether entrenching works. `custom.routed`
  or `metrics.events.entrenched` does.
- Band width follows run count: 30 runs gives a win rate ±17 points at 95%.
  Do not assert 0.45 to 0.55 on 30 runs.
- Sweeps are questions. Put values on both sides of the knee you expect, and
  read the table rather than asserting every cell.
- Keep a suite under about 60 s (the report prints `duration_msec`). Shrink
  runs or the map before shrinking the assertion.
- Prove RED: break the rule the suite guards (set a multiplier to 1.0, remove
  a tag) and watch the assertion fail before trusting it.

## Reading a report

`src/artifacts/sim/<suite_id>/latest.json` points at the newest run;
`report.md` has the matchup table (win rates, draws, rounds, decisions), a
per-cell block (end reasons, per-faction damage/kills/survivors/hp share,
custom), and the assertion table with actual values. `report.json` has the
same plus every run's seed, winner, reason and rounds.

To replay one run: `./simulate.ps1 -Suite <id> -Runs 1 -Seed <seed> -Trace`
writes `trace.json` with the full event log and final state of that run.
The same seed in the viewer (`src/app/battle_viewer.gd`, R cycles seeds)
shows it on screen.
