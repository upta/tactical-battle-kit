# Automated validation and balancing: current state and proposal

Discussion draft, not yet built. Goal: use the kit to pit multiple AI
implementations against each other, and to test balance changes to unit
stats/capabilities, in an automatable and reviewable way.

## What the suite format already does

- **Matchups**: a suite lists explicit `{id, ai: {faction: ai_id}}` pairs.
  Any AI registered via `ai_scripts()` or `--register` can fill a slot, so
  two custom AI implementations can already be pitted against each other in
  one suite.
- **Overrides**: `unit_defs.<id>.<field>`, `ruleset.<key>`, `terrain_defs`,
  and `battle.<path>` are all reachable from a suite file, so "what if this
  unit's attack were 7" or "what if the ruleset's aura radius were 2" is one
  override block.
- **One-axis sweep**: `sweep: {path, values}` runs the whole matchup set
  once per value, with seeds offset consistently per run index so cells are
  paired (run 3 of cell A used the same seed as run 3 of cell B).
- **Aggregation and assertions**: win rate per faction, draw rate, round
  and decision counts, and folded event/def/custom metrics, checked with
  comparator assertions (`gte`, `eq`, etc.).
- **Determinism**: a suite seed plus run index reproduces any game; traces
  let a specific run be replayed and inspected.

This covers "does AI X beat AI Y" and "does this one stat change move a
metric" as long as you're willing to read the report by eye.

## Gaps

**Pitting AIs against each other**
- Matchups are hand-listed pairs. No round-robin over an AI list, no
  automatic side-swap to cancel first-mover/faction advantage, no per-AI
  standing across matchups, no pairwise win matrix.
- A suite runs one battle. A tournament that means anything needs several
  maps, not one.

**Balancing stats and capabilities**
- Sweeps are one-dimensional. "Attack 5..8 crossed with defense 1..3" is a
  grid the format can't express as a single suite.
- No baseline concept. You can assert an absolute threshold but not "within
  5 points of the current build," and the report shows raw values, not
  deltas or confidence intervals — a 4-point swing over 30 runs reads as a
  finding when it may be noise.
- Capabilities are only sweepable if the ruleset already exposes them as a
  def field or flag; that pattern works but isn't documented.
- Nothing searches a range for you. Finding "the attack value that makes
  this mirror match 50/50" is still manual trial and error.

## Proposed additions, in order

1. **Tournament mode.** A suite gains a `tournament` block:
   `{"ais": [...], "battles": [...], "swap_sides": true}`. It expands to
   every ordered AI pair on every listed battle. The report adds per-AI win
   rate, a pairwise win matrix, and a simple Elo column. Assertions can
   target `standings.<ai>.win_rate`.
2. **Baseline and deltas.** A suite can mark one cell (usually the
   unswept build) as `"baseline"`. Every other cell's report shows a delta
   and a binomial confidence interval per metric, and assertions can be
   relative: `{"within": 0.05, "of": "baseline"}`. This is what makes stat
   changes reviewable instead of eyeballed.
3. **Grid sweeps.** `sweep` accepts a list of `{path, values}` entries;
   cells become the cross product, and the report prints one table per
   secondary axis.
4. **Balance search tool.** A headless CLI that takes an override path, a
   target metric and value, and bounds, then bisects with paired seeds
   until the metric lands within tolerance. "Find the cavalry attack value
   that makes the mirror match 50/50" becomes one command with a citable
   result.
5. **Parallel runs.** `simulate.ps1` currently runs suites serially.
   Tournaments multiply run counts, so running suites (or cells within one)
   across worker processes is close to a free 3-4x.
6. **Per-def usage metrics from events.** Actions per kind per def,
   time-to-first-kill, etc., so a stat change shows *how* play changed, not
   just who won.

Items 1 and 2 change what questions can be asked at all; 3-6 make the
answers faster and sharper. Each is a schema change to suite JSON or the
report format, so each should go through the architecture-proposal gate on
its own before implementation.
