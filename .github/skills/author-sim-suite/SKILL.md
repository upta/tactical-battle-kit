---
name: author-sim-suite
description: "Use when a balance or AI question should become a headless sim suite: interview the user one question at a time (never assume they remember a field), pick the suite form, write the JSON, prove it can fail, then hand off to run-sim-suite."
---

# Author a sim suite

A suite is a claim about the game that the kit can check by playing a
battle many times. The agent writes the JSON; the human answers questions.
The schema, override roots and metric paths are in the run-balance-sim
skill; do not restate them, read them.

## How to interview

Grill-me style: **one question per turn**, wait for the answer, then the
next. Never present the whole list and never assume the user remembers what
a suite needs. Each question offers a recommended default so "yes" is a
valid answer. Anything the codebase already knows is not a question: read
the ruleset's `ai_scripts()` for AI ids, the battle file for faction ids,
the def or ruleset for a tunable's shipped value. Stop asking when every
item in the checklist has an answer, and say which answers you filled in
yourself.

## The checklist (what must be known before writing)

1. **The claim**, one sentence a designer would say: "cavalry attack 7 is
   still fair", "the garrison AI beats random", "which of my AIs is best".
2. **The metric that moves if the claim is false.** `win_rate.<faction>`
   for balance, `standings.<ai>.win_rate` or `matrix.<a>.<b>` for AI
   ranking, `metrics.events.<type>` or `custom.<leaf>` for "does the
   mechanic happen". `metrics.events.rejected eq 0` proves only that the AI
   never chose an illegal action; add it, but it is not the claim.
3. **The form**, from the claim:

   | The question is about | Form | Keys |
   | --- | --- | --- |
   | One matchup on one battle | matchup | `battle`, `matchups` |
   | A tunable, compared to today | sweep + baseline | `sweep`, `baseline`, `within` assertions |
   | Which AI is best, across maps | tournament | `tournament` (replaces `battle` + `matchups`) |

4. **The battle**: a path under the project, or inline. Confirm its faction
   ids and that it has exactly two factions if this is a tournament.
5. **The AIs** per faction, by registered id. An AI the ruleset does not
   ship needs a pack script and a `register` entry; offer to write the pack.
6. **The tunable** (sweep and baseline only): its override path
   (`unit_defs.<id>.<field>`, `ruleset.<key>`, `terrain_defs.<id>.<field>`,
   `battle.<path>`) and its **shipped value, read from the file**. The
   baseline is the shipped value unless the user says otherwise.
7. **The values**: on both sides of the knee the user expects, three to
   five of them. A sweep is a question; the table answers it.
8. **Runs**: the interval must be narrower than the effect being looked
   for. Offer this table and ask what effect size matters:

   | Runs | Win-rate interval (95%) |
   | --- | --- |
   | 30 | about ±17 points |
   | 60 | about ±12 |
   | 120 | about ±9 |
   | 300 | about ±6 |

   Keep a suite under about a minute; shrink runs or the map before
   shrinking the claim.
9. **Assertions**: only what must hold for the table to mean anything.
   Absolute thresholds come from an existing claim in another suite or from
   the user, never from what one seed happened to produce. Relative ones
   are `{"metric", "within": x, "of": "baseline"}`.
10. **Id and description**: `suite_id` is the file name; `description` is
    the claim plus how to read the report, one or two sentences.

## Then

1. Write `sim/suites/<suite_id>.json` from the matching template below.
2. **Prove RED** before trusting it: run once with an `overrides` block that
   disables the mechanic, or with a deliberately wrong `expected`, and
   watch the `FAILED` line. Then revert. A suite that has never failed
   proves nothing.
3. Run it for real (run-sim-suite skill) and read `report.md`.
4. If an assertion fails, decide with the user whether the claim was wrong
   or the threshold was; never tune a number to the seed.
5. Hand off: the run-sim-suite skill writes the analysis and the page.

## Templates

Matchup:

```json
{
  "suite_id": "garrison_beats_random",
  "description": "The shipped garrison AI holds the outpost against random raiders.",
  "battle": "res://battles/outpost.json",
  "runs": 40, "seed": 200,
  "matchups": [{"id": "garrison_vs_random", "ai": {"garrison": "garrison", "raiders": "random"}}],
  "assertions": [
    {"metric": "win_rate.garrison", "comparator": "gte", "expected": 0.8},
    {"metric": "metrics.events.rejected", "comparator": "eq", "expected": 0}
  ]
}
```

Sweep with baseline:

```json
{
  "suite_id": "raider_attack_baseline",
  "description": "One more point of raider attack: does the garrison still hold, and by how much less?",
  "battle": "res://battles/outpost.json",
  "runs": 60, "seed": 500,
  "register": ["res://ai/raider_pack.gd"],
  "matchups": [{"id": "garrison_vs_rush", "ai": {"garrison": "garrison", "raiders": "rush"}}],
  "sweep": {"path": "unit_defs.raider.attack", "values": [5, 6, 7]},
  "baseline": {"sweep_value": 5},
  "assertions": [
    {"metric": "ci95.win_rate.garrison", "comparator": "lte", "expected": 0.15},
    {"metric": "mean_rounds", "within": 3, "of": "baseline"}
  ]
}
```

Tournament:

```json
{
  "suite_id": "ai_tournament",
  "description": "Every AI against every other, both sides; the standings table is the answer.",
  "runs": 30, "seed": 400,
  "register": ["res://ai/raider_pack.gd"],
  "tournament": {"ais": ["random", "garrison", "rush"], "battles": ["res://battles/outpost.json"], "swap_sides": true},
  "assertions": [
    {"metric": "matrix.garrison.random", "comparator": "gte", "expected": 0.6},
    {"metric": "standings.rush.games", "comparator": "eq", "expected": 120}
  ]
}
```

## Traps

- A tunable that is not an exported def field or a `configure()` key is
  not sweepable; say so and offer the ruleset change first.
- `sweep_value` in an assertion must equal the value as JSON parses it
  (numbers are floats); `matchup` must equal the cell id, and tournament
  cells are `<battle_id>:<first>_vs_<second>`.
- Tournament battles need exactly two factions and AIs that understand
  their ruleset; the kit does not check the second.
- A new `class_name` (an AI, a pack) needs an import before the run;
  `simulate.ps1` does it, the raw command does not.
