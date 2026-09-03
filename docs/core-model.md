# Core model

Everything under `addons/tactical_battle_kit/core/` is a plain script: no
nodes, no signals, no scene tree. A battle is a `BattleState`, the only thing
that changes it is a `BattleEngine`, and everything that happened is in
`state.events`.

## Objects

| Type | Holds |
| --- | --- |
| `BattleState` | `grid`, `units` by id, `factions` in declared order, `faction_ai`, `round_number`, `current_turn`, `ended`, `outcome`, `custom`, `events`. `clone()` deep-copies grid, units, turn and custom. |
| `BattleGrid` | `width`, `height`, `topology`, named layers (`terrain` holds `TerrainDef`s), an overlay stack per cell. `terrain_at` is the top of the stack; `terrain_stack` is all of it. |
| `GridTopology` | `neighbors`, `distance`, `direction_to`, `arc`, `offset_cell`, `rotate_offset`, `line`, `cells_within`, `ring`. `SquareTopology` (4, 8, euclidean) and `HexTopology` (odd-r). |
| `BattleUnit` | `id`, `faction`, `def`, `cell` (anchor), `hp`, `facing`, `layer`, `status`, `spent`, `move_used`, `custom`. `is_alive()` is not dead; `is_on_field()` is status active. |
| `UnitDef` / `TerrainDef` | Resources. Subclass for game fields; `apply_overrides` patches any exported property. |
| `BattleAction` | `kind` (rule id), `unit_id`, `params`. |
| `BattleTurn` | `faction`, `unit_ids`, `phase`, `actions` taken, `custom`. |
| `BattleOutcome` | `winner` ("" for a draw), `reason`. |
| `BattleRng` | Seeded; `fork(label)` derives an independent stream. |

## The engine

`BattleEngine.new(ruleset)` resolves the rules and damage model once. Then:

- `legal_actions(state, turn)`: union of every rule's `enumerate` for the
  turn's units that `ruleset.unit_can_act`, skipping rules whose slot is
  spent. Cached by state instance and event count.
- `apply(state, action, rng)`: rejects (one `rejected` event) unless the
  action equals a legal one; otherwise the rule's `apply` runs, slots are
  spent, the action is recorded on the turn, and `check_outcome` is polled.
  Returns the events produced. Re-entrant: hooks may call it.
- Loop primitives: `start_battle`, `begin_round`, `next_turn` (null ends the
  round), `is_turn_over`, `end_turn`, `end_round` (draws at `max_rounds`).
  `BattleSimulator.run` and `BattleRunner.step` compose them identically.
- Transitions for rules and hooks: `emit`, `kill`, `remove_from_field`,
  `spawn`, `interrupt_move`, `end_battle`, `poll_outcome`, and
  `apply_reaction` for an action by a unit outside the turn. `engine.rng` is
  the stream hooks roll from.

## Events

Every event is a dictionary with `type` and `round`. Kit types and their keys:

| Type | Keys |
| --- | --- |
| `battle_started`, `battle_ended {winner, reason}` | |
| `round_started`, `round_ended` | |
| `turn_started {faction, phase, unit_ids}`, `turn_ended {faction, phase, action_count}` | |
| `stepped {unit_id, from, to}` | one per cell entered |
| `moved {unit_id, from, to, path, cost, interrupted}` | |
| `attacked {attacker_id, defender_id, damage, counter, defender_hp}` | games add `hit`, `chance`, `reaction`, ... |
| `ability_used {unit_id, ability, anchor, cells}` | |
| `healed {unit_id, by, amount, hp}` | |
| `unit_died {unit_id, killer_id}`, `left_field {unit_id, status, by}`, `unit_spawned {unit_id, faction, cell}` | |
| `waited {unit_id}`, `rejected {unit_id, action, reason}` | |

Cells are `[x, y]` arrays. Games add their own types freely. The
simulator's `fold_metrics` reads `attacked`, `healed`, `unit_died`,
`left_field` and counts every type; the ruleset's `summarize` reads whatever
it wants. Nothing else derives facts by diffing state.

## Determinism

`BattleSimulator` takes one `BattleRng` per battle and forks `engine` and
`ai:<faction>` streams, so an AI that rolls more often does not shift the
damage rolls. Rules and AIs must draw only from the rng they are handed.
`fold_metrics` and aggregation are pure functions of the results. Same seed,
same battle, on any machine; suites pin seeds and run `seed + i`.

## Occupancy

`state.occupied_cells(unit)` expands the def's footprint through the
topology; `unit_at(cell, layer)` and `units_at(cell)` answer who covers a
cell; `distance_between` is the minimum over footprint pairs. Units on
different layers share cells. `Pathfinder` validates the whole footprint at
every step and builds a blocker map once per search.
