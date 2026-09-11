---
name: run-sim-suite
description: "Use to run one sim suite or all of them, read the verdict and the report, write the analysis, render the report page with the analysis in it, and hand the user a URL to open. Also how to replay one seed with a trace."
---

# Run a sim suite

The kit is the test runner; this skill is the loop around it. Schema and
metric paths live in the run-balance-sim skill; writing a new suite is the
author-sim-suite skill.

## Run

```powershell
./simulate.ps1                          # every suite under sim/suites
./simulate.ps1 -Suite <suite_id>        # one
./simulate.ps1 -Suite <suite_id> -Runs 300 -Seed 7
```

Or the raw command on any platform (import first when a `class_name` was
added):

```
godot --headless --path . --script res://addons/tactical_battle_kit/sim/sim_cli.gd -- --suites res://sim/suites
godot --headless --path . --script res://addons/tactical_battle_kit/sim/sim_cli.gd -- --suite res://sim/suites/<suite_id>.json
```

Read the output bottom-up: `SUMMARY` (or the one `RESULT`) is the verdict,
`FAILED` lines name what did not hold, every `ARTIFACTS` line is followed
by a `URL` line for that run's page, and any `ERROR:` line means the run
itself is suspect regardless of the verdict.

## Read

1. `artifacts/sim/summary.md` (a `--suites` run): one row per suite.
2. `artifacts/sim/<suite_id>/latest.json` points at the newest run;
   `report.md` there has the cell table with `62% ±9` intervals, the
   deltas table when the suite has a baseline, the standings and matrix
   when it is a tournament, a per-cell block, and the assertion table.
3. Read the numbers against their intervals. A delta smaller than the
   intervals beside it is noise; a suite that reads differently at another
   seed is telling you its runs are too few, not that the game changed.
4. A `FAILED` assertion is a question for the user: was the claim wrong,
   or the threshold? Never move a threshold to what one seed produced.

## Write the analysis

Write `analysis.md` in the run directory (the `ARTIFACTS` path). Headings,
paragraphs, `-` bullets, `**bold**` and `` `code` `` render; keep it to
what a designer needs:

```markdown
# Reading
One paragraph: what the table says about the claim, with the numbers and their intervals.

- What moved and by how much, against the noise.
- What did not move that someone might expect to.
- Recommendation, or the next question to ask.
```

## Render and show

```
godot --headless --path . --script res://addons/tactical_battle_kit/sim/sim_cli.gd -- --render res://artifacts/sim/<suite_id>/<timestamp>
```

It prints `RENDERED <path>` and `URL file:///...`. **Give the user that
URL, verbatim, as the last line of your message**, so they can open the
page with the analysis at the top; if the environment has a browser or
artifact tool, open it there as well, but the URL is the deliverable. The
page is self-contained and works from disk.

Run directories are transient (gitignored artifacts). A conclusion worth
keeping goes into the suite's `description` and assertions, or a decision
record; say where you put it.

## Replay one run

`./simulate.ps1 -Suite <id> -Runs 1 -Seed <seed> -Trace` writes
`trace.json` with that run's full event log and final state; seeds are in
`report.json` per run. The same seed in the viewer shows it on screen.
