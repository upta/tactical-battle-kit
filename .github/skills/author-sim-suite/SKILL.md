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

Grill-me style: **one question per turn**, wait, then the next. Never
present the whole list and never assume the user remembers what a suite
needs. The checklist below is **yours, not theirs**: it says what you must
know before writing, not what you say. The user is a designer asking about
their game, so:

- **Talk like a colleague.** Not "First question, the claim. My default:"
  but "Want me to just see how the garrison's hold rate moves as sentry HP
  goes 9, 12, 15, 18, or is there something specific you're checking?"
  Every question carries its suggested answer so "yes" or "fine" works.
- **No schema in the conversation.** No metric paths, JSON keys, assertion
  syntax or comparator names in a question or a summary. You translate:
  `win_rate.garrison` is "how often the garrison holds",
  `ci95.win_rate.garrison lte 0.15` is "it was run enough times to read"
  (at the checked-in run counts that bound cannot fail on the data; it
  guards against a re-run with fewer runs), `metrics.events.rejected eq 0`
  is "the AI never made an illegal move", `baseline` is "compared to
  today's value". The JSON is written once at the end; show it only if
  asked.
- **Ask only what you cannot read or infer.** The codebase knows AI ids,
  faction ids and shipped values; read them and say what you found in one
  sentence. "Just seeing how it plays out" answers the claim, the
  assertions and usually the values in one go, so a routine question is
  two or three exchanges, not six. If the user's first message already
  names the tunable and a value, the only questions left are usually the
  range and whether they want it fast or precise.
- **Explain a number by what it buys.** "60 runs is about 13 seconds and
  shows a swing of 15 points or more; 120 resolves a 10-point difference
  and takes 25 seconds" is right. "±0.12 at n=60" is not.
- **Close in plain words.** Before running: "Wrote `sim/suites/sentry_hp.json`:
  four games' worth of sentry HP against the rush AI, 60 runs each, and it
  fails if 9 HP ever holds the outpost, if 15 ever loses it, or if an AI
  makes an illegal move." Then say which answers you filled in yourself.

## The checklist (what you must know before writing; never recite it)

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
   are `{"metric", "within": x, "of": "baseline"}`. A sweep suite needs at
   least one absolute assertion on a cell far from the baseline (the
   losing end, the lockout end), with the threshold several intervals
   away from the number; otherwise four identical cells pass, and a sweep
   that stopped applying is invisible.
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
    {"metric": "win_rate.garrison", "sweep_value": 6, "comparator": "lte", "expected": 0.2},
    {"metric": "mean_rounds", "sweep_value": 6, "comparator": "lte", "expected": 5.0},
    {"metric": "ci95.win_rate.garrison", "comparator": "lte", "expected": 0.15}
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
