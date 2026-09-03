# Presentation contract

Everything below the view is render-free. A game that owns its look
implements five things; the debug `BattleView` and the breach demo
(`examples/breach/`, a painted TileMapLayer map) are the two references.

## 1. Cell to world and back

The kit speaks `Vector2i` cells. Provide both directions:

- `BattleView`: `cell_center(cell)` and `cell_at_position(local)` from a
  cell size.
- TileMapLayer: `map_to_local(cell + origin)` and `local_to_map(local) -
  origin`, where `origin` is `TileMapGridSource.origin(ground)`; Godot's
  stacked hex layout with a horizontal offset axis is the kit's odd-r.

## 2. The map

Either the battle file's ASCII rows or a painted map. For a painted map the
TileSet carries a `terrain` String custom data field naming a terrain id on
every ground tile, overlay layers (cover, fences) use the same field, and any
extra custom data field listed in the battle file's `data_layers` becomes a
grid layer (heights, spawn flags). `TileMapGridSource` reads tile data only,
so sims run on the painted map headless. The TileMapLayers are the source of
truth; edit them in the editor.

## 3. Units from state

Draw every `unit.is_on_field()` at its cell (footprints through
`state.occupied_cells`), hp from `hp_fraction()`, facing from `unit.facing`
through `topology.direction_offset`, stances from `unit.custom`. Redraw on
`BattleRunner.state_changed`.

## 4. Effects from events

`BattleRunner.action_applied(action, events)` hands over exactly the events
one decision produced. Animate from those, never by diffing state:
`stepped`/`moved` (path to tween along), `attacked` (damage, `hit`,
`counter`, game extras like `chance` and `reaction`), `healed`, `unit_died`,
`left_field`, `unit_spawned`, `ability_used` (cells), and any game type
(breach's `cover_destroyed` erases a Cover tile).

## 5. A person deciding

Give a faction a `HumanController` through `runner.set_controller`. On
`decision_requested(turn, legal)`:

- ring `ActionTargets.actionable_unit_ids(legal)`;
- when a unit is selected, highlight `ActionTargets.target_cell_of(state,
  action)` for its actions (occupied by an enemy: attack, empty: move or
  act there, `anchor` param: area), and offer
  `ActionTargets.untargeted(state, legal, unit_id)` as buttons;
- on a click, `ActionTargets.matches_at(state, legal, unit_id, cell)`: one
  match submits, several show a chooser, none reselects;
- always offer End turn as `submit(null)`.

Then `human.submit(action)`; the runner resumes. Restarting while a decision
is pending: `runner.abort()`, then `submit(null)` so the suspended step
unwinds before `setup()` replaces the battle.

## Driving it

`runner.setup(state, ai_ids, seed)`, then `await runner.step()` per
decision (a timer for AI turns; a human turn suspends inside `step` until
submit). `battle_ended(outcome)` closes it. The breach scene exposes this as
`load_battle / factions / start / stop / step / set_paused / restart`, which
is the contract the dev shell's start menu drives for any presentation.
