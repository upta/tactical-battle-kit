class_name BattleState
extends RefCounted

## Everything about a battle in progress, with no nodes in it. The engine
## mutates it, rules and AIs read it, the view draws it, and the simulator
## builds and discards thousands per second. clone() is a deep copy safe for
## lookahead: grid, units, turn and custom are all duplicated.

var battle_id: String = ""
var ruleset: BattleRuleset
var grid: BattleGrid
var units: Dictionary[String, BattleUnit] = {}
## Declared faction order; the default scheduler walks it.
var factions: Array[String] = []
## AI id per faction as declared by the battle file. Advisory: the simulator
## and runner resolve it, the engine never reads it.
var faction_ai: Dictionary[String, String] = {}
var round_number: int = 0
var current_turn: BattleTurn = null
var ended: bool = false
var outcome: BattleOutcome = null
## Game-specific battle state (decks, supply, weather, schedulers' cursors).
var custom: Dictionary = {}
## Every event emitted, in order. The source of truth for what happened.
var events: Array[Dictionary] = []


func add_unit(unit: BattleUnit) -> void:
	if units.has(unit.id):
		push_error("Duplicate unit id '%s'." % unit.id)
		return
	units[unit.id] = unit
	if not factions.has(unit.faction):
		factions.append(unit.faction)


func unit(unit_id: String) -> BattleUnit:
	return units.get(unit_id)


func sorted_unit_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(units.keys())
	ids.sort()
	return ids


# --- Occupancy ---


func occupied_cells(target: BattleUnit) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset: Vector2i in target.def.footprint:
		cells.append(grid.topology.offset_cell(target.cell, offset))
	return cells


## Occupied cells [param target] would have with its anchor at [param anchor].
func footprint_at(target: BattleUnit, anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset: Vector2i in target.def.footprint:
		cells.append(grid.topology.offset_cell(anchor, offset))
	return cells


## The on-field unit covering [param cell] on [param layer], or on any layer
## when [param layer] is "*". null when empty.
func unit_at(cell: Vector2i, layer: String = "*") -> BattleUnit:
	for unit_id: String in sorted_unit_ids():
		var candidate := units[unit_id]
		if not candidate.is_on_field():
			continue
		if layer != "*" and candidate.layer != layer:
			continue
		if occupied_cells(candidate).has(cell):
			return candidate
	return null


## Every on-field unit covering [param cell], all layers.
func units_at(cell: Vector2i) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit_id: String in sorted_unit_ids():
		var candidate := units[unit_id]
		if candidate.is_on_field() and occupied_cells(candidate).has(cell):
			result.append(candidate)
	return result


## Shortest distance between any cell of [param a] and any cell of [param b].
func distance_between(a: BattleUnit, b: BattleUnit) -> int:
	var best := -1
	for cell_a: Vector2i in occupied_cells(a):
		for cell_b: Vector2i in occupied_cells(b):
			var d := grid.distance(cell_a, cell_b)
			if best < 0 or d < best:
				best = d
	return best


# --- Faction queries ---


## Units of one faction in a stable order (by id), whatever their status.
func units_of(faction: String) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit_id: String in sorted_unit_ids():
		var candidate := units[unit_id]
		if candidate.faction == faction:
			result.append(candidate)
	return result


func units_on_field_of(faction: String) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for candidate: BattleUnit in units_of(faction):
		if candidate.is_on_field():
			result.append(candidate)
	return result


func units_on_field() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit_id: String in sorted_unit_ids():
		var candidate := units[unit_id]
		if candidate.is_on_field():
			result.append(candidate)
	return result


## On-field units hostile to [param faction] per the ruleset.
func enemies_on_field_of(faction: String) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit_id: String in sorted_unit_ids():
		var candidate := units[unit_id]
		if candidate.is_on_field() and ruleset.are_enemies(faction, candidate.faction):
			result.append(candidate)
	return result


func factions_on_field() -> Array[String]:
	var result: Array[String] = []
	for faction: String in factions:
		if not units_on_field_of(faction).is_empty():
			result.append(faction)
	return result


func hp_share(faction: String) -> float:
	var total := 0
	var current := 0
	for candidate: BattleUnit in units_of(faction):
		total += candidate.def.max_hp
		if candidate.is_alive():
			current += clampi(candidate.hp, 0, candidate.def.max_hp)
	if total == 0:
		return 0.0
	return float(current) / float(total)


# --- Events, copy, export ---


func log_event(event: Dictionary) -> void:
	event["round"] = round_number
	events.append(event)


func clone() -> BattleState:
	var copy := BattleState.new()
	copy.battle_id = battle_id
	copy.ruleset = ruleset
	copy.grid = grid.clone()
	for unit_id: String in units.keys():
		copy.units[unit_id] = units[unit_id].clone()
	copy.factions = factions.duplicate()
	copy.faction_ai = faction_ai.duplicate()
	copy.round_number = round_number
	copy.current_turn = current_turn.clone() if current_turn != null else null
	copy.ended = ended
	copy.outcome = outcome
	copy.custom = custom.duplicate(true)
	copy.events = events.duplicate()
	return copy


func to_dict() -> Dictionary:
	var unit_dicts: Array = []
	for unit_id: String in sorted_unit_ids():
		unit_dicts.append(units[unit_id].to_dict())
	return {
		"battle_id": battle_id,
		"ruleset": ruleset.id() if ruleset != null else "",
		"grid": grid.to_dict() if grid != null else {},
		"factions": factions.duplicate(),
		"round": round_number,
		"turn": current_turn.to_dict() if current_turn != null else {},
		"ended": ended,
		"outcome": outcome.to_dict() if outcome != null else {},
		"units": unit_dicts,
		"custom": DefOverrides.jsonify(custom),
		"event_count": events.size(),
	}
