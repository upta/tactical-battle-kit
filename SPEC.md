# Spec

Design intent for the kit. Mechanics of the example games belong in their
rulesets and battle files, not here.

## What this is for

A rules engine a grid-tactics game drops in so it can spend its time on the
game: its units, its rules, its AI, its presentation. And a harness that
answers balance questions with numbers before a human plays a single turn:
"is cavalry too strong", "does moving first decide the mirror", "how much
does supply matter", asked as a JSON suite and answered as a table with
assertions that fail in CI.

Consumers are GDScript Godot projects, often jam-sized, often driven by an
agent. The kit has to be small enough to read in an afternoon and strict
enough that an agent cannot bolt game logic onto the engine.

## The bar

A game author must be able to express every mechanic in the seven reference
games (Warsong/Langrisser, chess, Gemfire, Liberty or Death, Shining Force /
FFT, XCOM, D&D) without editing the addon. When they cannot, that is a kit
change with a proposal, never a workaround in the game.

A suite must be able to reach any tunable a designer would want to sweep:
def fields, ruleset parameters, army composition. A metric must be
explainable from the event log or the ruleset's own summary.

## Pillars

- **No game logic in the engine.** Dispatch, bookkeeping, events, outcome
  polling. Everything else is a strategy on the ruleset.
- **Events are the truth.** What happened is the log; metrics, views,
  reports and hooks read it. A change nobody emitted did not happen.
- **Deterministic.** Same seed, same battle, on any machine. One `BattleRng`
  per battle, forked per purpose.
- **Node-free below the view.** Thousands of battles per second headless;
  the same state drives a scene.
- **Proof before people.** Suites for rules and balance, scenarios for
  pixels, both RED first.

## Non-goals

- Continuous space, rotating footprints, true line-of-sight geometry beyond
  `topology.line`.
- Presentation. `BattleView` is a debug renderer; games own their look.
- Campaign layer: persistence between battles, XP carry-over, army building.
- Strong AI. Shipped AIs prove the seams and give baselines, nothing more.
- Networking.

## Open questions

- Occupancy index: `unit_at` scans; at what unit count does it need an index
  behind the same three methods?
- Multi-dimensional sweeps: one path per suite today; two-axis grids are a
  report-shape change.
- Hidden information: simultaneous card selection is honest only if AIs do
  not read other factions' `custom`; nothing enforces it.
