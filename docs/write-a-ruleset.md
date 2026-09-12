# Write a ruleset

One class, `extends BattleRuleset`, is the whole game from the engine's point
of view. Only `action_rules()` is required; every other method has a default
that gives classic grid tactics. The full signature list is in
`strategy/battle_ruleset.gd`; the mechanic-to-seam table and the traps are in
`.github/skills/author-battle-ruleset/SKILL.md`.

## Minimal

```gdscript
class_name MyRuleset
extends BattleRuleset


func id() -> String:
	return "my_game"


func action_rules() -> Array[ActionRule]:
	return [MoveRule.new(), AttackRule.new(), WaitRule.new()]
```

That is a playable game: faction turns, move then attack, counterattacks at
half strength, elimination victory, linear damage with terrain defense,
thirty-round draw.

## Adding a mechanic

Pick the seam from the table, override the method, emit events for anything
that changes state. Three shapes cover almost everything:

**A strategy override** (movement, alliances, outcome):

```gdscript
func movement_cost(state: BattleState, unit: BattleUnit, cell: Vector2i) -> int:
	if unit.def.has_tag("cavalry") and state.grid.has_tag_at(cell, "forest"):
		return -1
	return super(state, unit, cell)
```

Three movement strategies sit beside the cost and answer questions a cost
cannot: `can_pass_through(state, mover, other)` for occupied cells,
`can_stop_at(state, unit, cell)` for cells a unit may cross but never end
on (a flyer over a wall), and `can_continue_from(state, unit, cell)` for
cells a unit may end on but never walk past (a zone of control beside an
enemy). The pathfinder still offers such a cell as a destination; it only
stops searching beyond it. The mover's own cell always expands.

**A template step** (attack variants, area effects):

```gdscript
class_name VolleyRule
extends AttackRule


func after_attack(state: BattleState, engine: BattleEngine, attacker: BattleUnit, defender: BattleUnit) -> void:
	attacker.custom["powder"] = int(attacker.custom.get("powder", 0)) - 1
```

**A hook with engine access** (reactions, chain effects):

```gdscript
func on_event(state: BattleState, engine: BattleEngine, event: Dictionary) -> void:
	if str(event.get("type")) == BattleEvents.UNIT_DIED:
		var fallen := state.unit(str(event.get("unit_id")))
		for troop: BattleUnit in state.units_on_field_of(fallen.faction):
			if str(troop.custom.get("commander", "")) == fallen.id:
				engine.remove_from_field(state, troop, "dissolved", fallen.id)
```

## A new action

```gdscript
class_name EntrenchRule
extends ActionRule


func id() -> String:
	return "entrench"


func ends_activation() -> bool:
	return true


func enumerate(_state: BattleState, unit: BattleUnit) -> Array[BattleAction]:
	return [make_action(unit)]


func apply(state: BattleState, engine: BattleEngine, action: BattleAction, _rng: BattleRng) -> void:
	var unit := state.unit(action.unit_id)
	unit.custom["entrenched"] = true
	engine.emit(state, {"type": "entrenched", "unit_id": unit.id})
```

`slot()` defaults to `"action"`; return `""` for something that spends
nothing. `ends_activation()` true spends every slot in
`activation_slots()`, so the unit cannot move afterwards; false spends only
the rule's slot and leaves the move slot usable. Override `spends()` for
conditional spending (the default
`MoveRule` spends `move` only when the ruleset says one move per activation
or the budget is used up).

## Scheduling

The default is one turn per faction with all its units. Override
`begin_round` and `next_turn` for anything else; keep the cursor in
`state.custom` because the ruleset instance is shared by clones. The frontier
example orders every unit by initiative; chess keeps the default scheduler
and ends the turn after one action through `is_turn_over`.

## Data

`make_unit_def` / `make_terrain_def` build defs from inline dictionaries and
are where a subclassed def is instantiated. `make_unit` applies per-instance
overrides (`hp`, `facing`, `layer`, `status`, `custom`) from the battle file.
`configure(params)` receives `ruleset.<key>` overrides from suites; keep
tunables as plain vars and read them there. `summarize(state)` returns
numbers for the report. `ai_scripts()` names the game's AIs.

## Reactions

Overwatch, opportunity attacks, anything that fires on the other side's
turn: the reaction is its own `ActionRule` with `slot()` returning "" and
`can_use` gating on the stance, and the hook fires it with
`engine.apply_reaction(state, action)`, which validates against that rule's
`enumerate` and skips the turn check (D15). `engine.interrupt_move` then
stops the mover mid-path. Roll from `engine.rng`. The breach example's
`ReactionShotRule` and its `on_event` are the reference.

## An AI

```gdscript
class_name MyAi
extends AiController


func choose(state: BattleState, engine: BattleEngine, turn: BattleTurn, rng: BattleRng) -> BattleAction:
	var actions := engine.legal_actions(state, turn)
	return rng.pick(actions) if not actions.is_empty() else null
```

Score `actions` however the game likes; `state.clone()` is available for
lookahead. A human player is a controller with `choose_async` that
`BattleRunner` awaits.
