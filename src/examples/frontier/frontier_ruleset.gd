class_name FrontierRuleset
extends BattleRuleset

## Liberty-or-Death flavored musket war on hexes: every unit acts in its own
## initiative turn, muskets and cannon spend gunpowder, entrenching halves
## incoming damage until the unit moves, a mauled unit routs and is captured
## when an enemy is adjacent, and an army whose supply runs out fights worse
## and breaks sooner. Exercises the per-unit scheduler, per-unit terrain,
## unit status, facing on hexes, and both sweep roots.

const ORDER_KEY := "initiative_order"
const SUPPLY_KEY := "supply"

var rout_threshold: float = 0.25
var starving_rout_threshold: float = 0.4
var starving_damage_multiplier: float = 0.7
var entrenched_multiplier: float = 0.5
var rear_multiplier: float = 1.5
var starting_powder: int = 6
## Zone of control: a cell beside an enemy can be entered but never passed
## through. Off by default so the other suites keep their baselines.
var zone_of_control: bool = false


func id() -> String:
	return "frontier"


func topology() -> GridTopology:
	return HexTopology.new()


func action_rules() -> Array[ActionRule]:
	return [MoveRule.new(), MusketAttackRule.new(), EntrenchRule.new(), WaitRule.new()]


func damage_model() -> DamageModel:
	return FrontierDamageModel.new(self)


func uses_facing() -> bool:
	return true


func max_rounds() -> int:
	return 25


## Cavalry and cannon cannot enter forest; rivers stop everyone.
func movement_cost(state: BattleState, unit: BattleUnit, cell: Vector2i) -> int:
	if state.grid.has_tag_at(cell, "forest") and (unit.def.has_tag("cavalry") or unit.def.has_tag("artillery")):
		return -1
	return super(state, unit, cell)


## With zone_of_control on, a cell beside an enemy ends the move.
func can_continue_from(state: BattleState, unit: BattleUnit, cell: Vector2i) -> bool:
	if not zone_of_control:
		return true
	for enemy: BattleUnit in state.enemies_on_field_of(unit.faction):
		if state.grid.distance(cell, enemy.cell) == 1:
			return false
	return true


# --- Per-unit initiative scheduler ---


func begin_round(state: BattleState) -> void:
	var order: Array[String] = []
	var units := state.units_on_field()
	units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.def.move != b.def.move:
			return a.def.move > b.def.move
		return a.id < b.id)
	for unit: BattleUnit in units:
		order.append(unit.id)
	state.custom[ORDER_KEY] = order


func next_turn(state: BattleState) -> BattleTurn:
	var order: Array = state.custom.get(ORDER_KEY, [])
	while not order.is_empty():
		var unit_id := str(order.pop_front())
		var unit := state.unit(unit_id)
		if unit == null or not unit.is_on_field():
			continue
		unit.reset_activation()
		return BattleTurn.new(unit.faction, [unit_id])
	return null


# --- Supply ---


func on_battle_started(state: BattleState, _engine: BattleEngine) -> void:
	if not state.custom.has(SUPPLY_KEY):
		state.custom[SUPPLY_KEY] = {}
	for unit: BattleUnit in state.units.values():
		if unit.def.has_tag("ranged") and not unit.custom.has("powder"):
			unit.custom["powder"] = starting_powder


func on_round_started(state: BattleState, _engine: BattleEngine) -> void:
	var supply: Dictionary = state.custom.get(SUPPLY_KEY, {})
	for faction: String in state.factions:
		supply[faction] = int(supply.get(faction, 0)) - 1


func is_starving(state: BattleState, faction: String) -> bool:
	var supply: Dictionary = state.custom.get(SUPPLY_KEY, {})
	return int(supply.get(faction, 0)) <= 0


## Moving abandons the trench.
func on_event(state: BattleState, _engine: BattleEngine, event: Dictionary) -> void:
	if str(event.get("type")) == BattleEvents.MOVED:
		var unit := state.unit(str(event.get("unit_id")))
		if unit != null:
			unit.custom.erase("entrenched")


func configure(params: Dictionary) -> void:
	rout_threshold = float(params.get("rout_threshold", rout_threshold))
	starving_rout_threshold = float(params.get("starving_rout_threshold", starving_rout_threshold))
	starving_damage_multiplier = float(params.get("starving_damage_multiplier", starving_damage_multiplier))
	entrenched_multiplier = float(params.get("entrenched_multiplier", entrenched_multiplier))
	rear_multiplier = float(params.get("rear_multiplier", rear_multiplier))
	starting_powder = int(params.get("starting_powder", starting_powder))
	zone_of_control = bool(params.get("zone_of_control", zone_of_control))


func summarize(state: BattleState) -> Dictionary:
	var routed := {}
	var captured := {}
	var powder := {}
	var starving_rounds := {}
	for faction: String in state.factions:
		routed[faction] = 0
		captured[faction] = 0
		powder[faction] = 0
		starving_rounds[faction] = maxi(0, -int((state.custom.get(SUPPLY_KEY, {}) as Dictionary).get(faction, 0)))
	for unit: BattleUnit in state.units.values():
		match unit.status:
			"routed":
				routed[unit.faction] = int(routed[unit.faction]) + 1
			"captured":
				captured[unit.faction] = int(captured[unit.faction]) + 1
		powder[unit.faction] = int(powder[unit.faction]) + int(unit.custom.get("powder", 0))
	return {
		"routed": routed,
		"captured": captured,
		"powder_left": powder,
		"starving_rounds": starving_rounds,
		"zoc_violations": zoc_violations(state),
	}


## Moves that passed through a cell beside an enemy: every step of a walked
## path except the last. Who stood where when each move was made is
## replayed from the moved and death events, since the final positions say
## nothing about the middle of the battle.
func zoc_violations(state: BattleState) -> int:
	var cells: Dictionary[String, Vector2i] = {}
	var alive: Dictionary[String, bool] = {}
	for unit: BattleUnit in state.units.values():
		cells[unit.id] = _start_cell(state, unit)
		alive[unit.id] = true
	var count := 0
	for event: Dictionary in state.events:
		var type := str(event.get("type", ""))
		if type == BattleEvents.UNIT_DIED or type == BattleEvents.LEFT_FIELD:
			alive[str(event.get("unit_id", ""))] = false
		if type != BattleEvents.MOVED:
			continue
		var mover := state.unit(str(event.get("unit_id", "")))
		var path: Array = event.get("path", [])
		for index: int in path.size() - 1:
			var step: Array = path[index]
			var cell := Vector2i(int(step[0]), int(step[1]))
			for other: BattleUnit in state.units.values():
				if alive.get(other.id, false) and are_enemies(mover.faction, other.faction) and state.grid.distance(cell, cells[other.id]) == 1:
					count += 1
					break
		if not path.is_empty():
			var last: Array = path[path.size() - 1]
			cells[mover.id] = Vector2i(int(last[0]), int(last[1]))
	return count


## Where a unit stood at the start: the origin of its first move, else where
## it is now.
func _start_cell(state: BattleState, unit: BattleUnit) -> Vector2i:
	for event: Dictionary in state.events:
		if str(event.get("type", "")) == BattleEvents.MOVED and str(event.get("unit_id", "")) == unit.id:
			var from: Array = event.get("from", [unit.cell.x, unit.cell.y])
			return Vector2i(int(from[0]), int(from[1]))
	return unit.cell


func ai_scripts() -> Dictionary[String, GDScript]:
	return {"frontier": FrontierAi}
