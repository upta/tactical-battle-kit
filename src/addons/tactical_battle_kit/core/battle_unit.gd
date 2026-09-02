class_name BattleUnit
extends RefCounted

## One unit on the field: a [UnitDef] plus the state that changes during a
## battle. Only what the engine needs to run the battle lives here; metrics
## are folded from the event log by the simulator, and game-specific runtime
## state goes in [member custom].

const STATUS_ACTIVE := "active"
const STATUS_DEAD := "dead"

var id: String = ""
var faction: String = ""
var def: UnitDef
## Anchor cell; the footprint expands from here.
var cell: Vector2i = Vector2i.ZERO
var hp: int = 0
## Direction index from the topology, -1 when the ruleset does not use facing.
var facing: int = -1
## Occupancy layer; copied from the def at creation, mutable (a unit takes off).
var layer: String = ""
## "active" is on the field. "dead", "routed", "captured", "dormant" or any
## game-defined status is off the field; only "dead" counts as not alive.
var status: String = STATUS_ACTIVE
## Activation slots spent this activation ("move", "action", ...).
var spent: Array[String] = []
## Movement budget used this activation, in movement points.
var move_used: int = 0
## Game-specific runtime state. Deep-copied by clone().
var custom: Dictionary = {}


func _init(unit_id: String = "", unit_faction: String = "", unit_def: UnitDef = null, start_cell: Vector2i = Vector2i.ZERO) -> void:
	id = unit_id
	faction = unit_faction
	def = unit_def
	cell = start_cell
	if def != null:
		hp = def.max_hp
		layer = def.layer


func is_alive() -> bool:
	return status != STATUS_DEAD


func is_on_field() -> bool:
	return status == STATUS_ACTIVE


func has_spent(slot: String) -> bool:
	return spent.has(slot)


func spend(slot: String) -> void:
	if slot != "" and not spent.has(slot):
		spent.append(slot)


func reset_activation() -> void:
	spent.clear()
	move_used = 0


func hp_fraction() -> float:
	if def == null or def.max_hp <= 0:
		return 0.0
	return clampf(float(hp) / float(def.max_hp), 0.0, 1.0)


func clone() -> BattleUnit:
	var copy := BattleUnit.new(id, faction, def, cell)
	copy.hp = hp
	copy.facing = facing
	copy.layer = layer
	copy.status = status
	copy.spent = spent.duplicate()
	copy.move_used = move_used
	copy.custom = custom.duplicate(true)
	return copy


func to_dict() -> Dictionary:
	return {
		"id": id,
		"faction": faction,
		"def": def.id if def != null else "",
		"cell": [cell.x, cell.y],
		"hp": hp,
		"max_hp": def.max_hp if def != null else 0,
		"facing": facing,
		"layer": layer,
		"status": status,
		"spent": spent.duplicate(),
		"move_used": move_used,
		"custom": DefOverrides.jsonify(custom),
	}
