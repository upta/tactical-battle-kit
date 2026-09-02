@abstract
class_name BattleRuleset
extends RefCounted

## The one object a game implements. Bundles every strategy the engine
## consults (actions, movement, damage, scheduling, outcome, alliances), the
## lifecycle hooks, and the factories the loader builds units and defs with.
## Every method except action_rules() has a default that gives classic
## grid tactics: faction turns, move then act, elimination victory.
##
## Hooks receive the engine so they can call apply(), remove_from_field(),
## interrupt_move() and end_battle(). apply() is re-entrant.

const _TURN_CURSOR := "__turn_cursor"


func id() -> String:
	return "ruleset"


# --- Actions ---


## The ActionRules this game offers, in enumeration order.
@abstract func action_rules() -> Array[ActionRule]


# --- Models ---


func topology() -> GridTopology:
	return SquareTopology.new()


func damage_model() -> DamageModel:
	return LinearDamageModel.new()


## Movement points for [param unit] to enter [param cell], -1 if impassable.
## Default: the cell's terrain stack, impassable if anything in it is, cost
## summed. Override for per-unit-type terrain (cavalry vs forest, flyers).
func movement_cost(state: BattleState, unit: BattleUnit, cell: Vector2i) -> int:
	var total := 0
	for terrain: TerrainDef in state.grid.terrain_stack(cell):
		if not terrain.passable:
			return -1
		total += terrain.move_cost
	return total


## May [param mover] pass through a cell occupied by [param other]? Default:
## allies yes, enemies no. Stopping on an occupied cell is never allowed.
func can_pass_through(state: BattleState, mover: BattleUnit, other: BattleUnit) -> bool:
	return not are_enemies(mover.faction, other.faction)


func move_budget(state: BattleState, unit: BattleUnit) -> int:
	return unit.def.move


## When true a unit's first move spends its move slot; when false it can
## keep moving until its budget is used (XCOM dash, D&D split movement).
func single_move() -> bool:
	return true


func are_enemies(faction_a: String, faction_b: String) -> bool:
	return faction_a != faction_b


func uses_facing() -> bool:
	return false


func max_rounds() -> int:
	return 30


# --- Activation ---


func activation_slots() -> Array[String]:
	return ["move", "action"]


## Default: on the field with at least one slot unspent.
func unit_can_act(state: BattleState, unit: BattleUnit) -> bool:
	if not unit.is_on_field():
		return false
	for slot: String in activation_slots():
		if not unit.has_spent(slot):
			return true
	return false


# --- Scheduling ---


## Default: every unit gets a fresh activation and the faction cursor resets.
func begin_round(state: BattleState) -> void:
	for unit: BattleUnit in state.units.values():
		unit.reset_activation()
	state.custom[_TURN_CURSOR] = 0


## Default: one turn per faction in declared order, all its on-field units,
## skipping factions with nobody on the field. null ends the round.
func next_turn(state: BattleState) -> BattleTurn:
	var cursor: int = state.custom.get(_TURN_CURSOR, 0)
	while cursor < state.factions.size():
		var faction := state.factions[cursor]
		cursor += 1
		state.custom[_TURN_CURSOR] = cursor
		var unit_ids: Array[String] = []
		for unit: BattleUnit in state.units_on_field_of(faction):
			unit_ids.append(unit.id)
		if not unit_ids.is_empty():
			return BattleTurn.new(faction, unit_ids)
	return null


## Default: nothing left to do.
func is_turn_over(state: BattleState, engine: BattleEngine, turn: BattleTurn) -> bool:
	return engine.legal_actions(state, turn).is_empty()


# --- Outcome ---


## null keeps the battle going. Polled after every applied action, at turn
## end and at round end. Default: elimination.
func check_outcome(state: BattleState) -> BattleOutcome:
	var standing := state.factions_on_field()
	if standing.size() == 1:
		return BattleOutcome.new(standing[0], "elimination")
	if standing.is_empty():
		return BattleOutcome.draw("mutual_elimination")
	return null


# --- Hooks (no-op) ---


func on_battle_started(_state: BattleState, _engine: BattleEngine) -> void:
	pass


func on_round_started(_state: BattleState, _engine: BattleEngine) -> void:
	pass


func on_turn_started(_state: BattleState, _engine: BattleEngine, _turn: BattleTurn) -> void:
	pass


func on_turn_ended(_state: BattleState, _engine: BattleEngine, _turn: BattleTurn) -> void:
	pass


func on_event(_state: BattleState, _engine: BattleEngine, _event: Dictionary) -> void:
	pass


# --- Factories ---


func make_unit_def(data: Dictionary) -> UnitDef:
	var def := UnitDef.new()
	def.apply_overrides(data)
	if not data.has("display_name"):
		def.display_name = def.id.capitalize()
	return def


func make_terrain_def(data: Dictionary) -> TerrainDef:
	var def := TerrainDef.new()
	def.apply_overrides(data)
	if not data.has("display_name"):
		def.display_name = def.id.capitalize()
	return def


## Instance overrides: hp, facing, layer, status, custom.
func make_unit(unit_id: String, def: UnitDef, faction: String, cell: Vector2i, overrides: Dictionary = {}) -> BattleUnit:
	var unit := BattleUnit.new(unit_id, faction, def, cell)
	if overrides.has("hp"):
		unit.hp = int(overrides["hp"])
	if overrides.has("facing"):
		unit.facing = int(overrides["facing"])
	if overrides.has("layer"):
		unit.layer = str(overrides["layer"])
	if overrides.has("status"):
		unit.status = str(overrides["status"])
	if overrides.has("custom"):
		unit.custom = (overrides["custom"] as Dictionary).duplicate(true)
	return unit


# --- Config and reporting ---


## AIs this game ships, registered with the AiRegistry when a battle using
## this ruleset is loaded: {ai_id: script extending AiController}. Scripts,
## not lambdas: a static registry of closures crashes the engine at exit.
func ai_scripts() -> Dictionary[String, GDScript]:
	return {}


## Sweep and override target: "ruleset.<key>" lands here.
func configure(_params: Dictionary) -> void:
	pass


## Game-specific numbers for the balance report, averaged per matchup.
## Nested dictionaries of numbers are fine; anything else is dropped.
func summarize(_state: BattleState) -> Dictionary:
	return {}
