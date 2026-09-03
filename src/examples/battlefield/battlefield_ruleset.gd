class_name BattlefieldRuleset
extends BattleRuleset

## Heroes of Might and Magic style battle on offset squares (hex adjacency):
## creature stacks whose hp pool is count times creature hp, per-unit
## initiative by speed with Wait pushing a stack to the end of the round, one
## retaliation per stack per round, ranged stacks with limited shots and a
## distance penalty, two-cell creatures, flyers that cross obstacles but
## cannot land on them, a lich death cloud that hits everything around its
## target including friends, and Defend. Exercises footprints, the
## per-unit scheduler, retaliation through the attack template, an AreaRule
## with friendly fire, and can_stop_at.

const ORDER_KEY := "initiative_order"
const DELAYED_KEY := "delayed_queue"

var range_penalty_distance: int = 5
var attack_defense_step: float = 0.05
var defend_bonus: int = 4


func id() -> String:
	return "battlefield"


func topology() -> GridTopology:
	return HexTopology.new()


func action_rules() -> Array[ActionRule]:
	return [MoveRule.new(), MeleeRule.new(), VolleyRule.new(), DeathCloudRule.new(), DefendRule.new(), DelayRule.new()]


func damage_model() -> DamageModel:
	return StackDamageModel.new(self)


func max_rounds() -> int:
	return 30


func make_unit_def(data: Dictionary) -> UnitDef:
	var def := StackDef.new()
	def.apply_overrides(data)
	if not data.has("display_name"):
		def.display_name = def.id.capitalize()
	var footprint: Array[Vector2i] = [Vector2i.ZERO]
	if def.size >= 2:
		footprint.append(Vector2i(1, 0))
	def.footprint = footprint
	return def


## The battle file gives a creature count; the stack's hp pool follows.
func make_unit(unit_id: String, def: UnitDef, faction: String, cell: Vector2i, overrides: Dictionary = {}) -> BattleUnit:
	var unit := super(unit_id, def, faction, cell, overrides)
	var stack := def as StackDef
	if stack != null:
		var count := int((overrides.get("custom", {}) as Dictionary).get("count", 1))
		unit.hp = count * stack.creature_hp
		unit.custom["shots"] = stack.shots
	return unit


# --- Movement ---


func movement_cost(state: BattleState, unit: BattleUnit, cell: Vector2i) -> int:
	if is_flying(unit) and state.grid.has_tag_at(cell, "obstacle"):
		return 1
	return super(state, unit, cell)


func can_stop_at(state: BattleState, _unit: BattleUnit, cell: Vector2i) -> bool:
	return not state.grid.has_tag_at(cell, "obstacle")


# --- Initiative scheduler ---


func begin_round(state: BattleState) -> void:
	var units := state.units_on_field()
	var first := state.factions[0] if not state.factions.is_empty() else ""
	units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		var sa := speed_of(a)
		var sb := speed_of(b)
		if sa != sb:
			return sa > sb
		if (a.faction == first) != (b.faction == first):
			return a.faction == first
		return a.id < b.id)
	var order: Array[String] = []
	for unit: BattleUnit in units:
		order.append(unit.id)
		unit.custom.erase("retaliated")
		unit.custom.erase("delayed")
	state.custom[ORDER_KEY] = order
	state.custom[DELAYED_KEY] = []


func next_turn(state: BattleState) -> BattleTurn:
	var order: Array = state.custom.get(ORDER_KEY, [])
	var delayed: Array = state.custom.get(DELAYED_KEY, [])
	while not order.is_empty() or not delayed.is_empty():
		var unit_id := str(order.pop_front()) if not order.is_empty() else str(delayed.pop_front())
		var unit := state.unit(unit_id)
		if unit == null or not unit.is_on_field():
			continue
		unit.reset_activation()
		unit.custom.erase("defending")
		unit.custom.erase("delayed")
		return BattleTurn.new(unit.faction, [unit_id])
	return null


func summarize(state: BattleState) -> Dictionary:
	var creatures := {}
	for faction: String in state.factions:
		var total := 0
		for unit: BattleUnit in state.units_on_field_of(faction):
			total += count_of(unit)
		creatures[faction] = total
	var casts := 0
	var friendly_damage := 0
	var retaliations := 0
	for event: Dictionary in state.events:
		match str(event.get("type", "")):
			BattleEvents.ABILITY_USED:
				if str(event.get("ability")) == "death_cloud":
					casts += 1
			BattleEvents.ATTACKED:
				if bool(event.get("friendly", false)):
					friendly_damage += int(event.get("damage", 0))
				if bool(event.get("counter", false)):
					retaliations += 1
	return {"creatures_left": creatures, "cloud_casts": casts, "cloud_friendly_damage": friendly_damage, "retaliations": retaliations}


func configure(params: Dictionary) -> void:
	range_penalty_distance = int(params.get("range_penalty_distance", range_penalty_distance))
	attack_defense_step = float(params.get("attack_defense_step", attack_defense_step))
	defend_bonus = int(params.get("defend_bonus", defend_bonus))


func ai_scripts() -> Dictionary[String, GDScript]:
	return {"battlefield": BattlefieldAi}


# --- Helpers the rules, AI and presentation share ---


static func count_of(unit: BattleUnit) -> int:
	var stack := unit.def as StackDef
	return stack.count_for(unit.hp) if stack != null else (1 if unit.is_alive() else 0)


static func is_flying(unit: BattleUnit) -> bool:
	var stack := unit.def as StackDef
	return stack != null and stack.flying


static func speed_of(unit: BattleUnit) -> int:
	var stack := unit.def as StackDef
	return stack.speed if stack != null else unit.def.move


static func shots_left(unit: BattleUnit) -> int:
	return int(unit.custom.get("shots", 0))


func has_adjacent_enemy(state: BattleState, unit: BattleUnit) -> bool:
	for enemy: BattleUnit in state.enemies_on_field_of(unit.faction):
		if state.distance_between(unit, enemy) <= 1:
			return true
	return false


## Damage range before the roll, for tooltips and the AI: {min, max, kills_min, kills_max}.
func expected_damage(state: BattleState, attacker: BattleUnit, defender: BattleUnit, ranged: bool) -> Dictionary:
	var model := damage_model() as StackDamageModel
	var low := model.compute_fixed(state, attacker, defender, 0.0, ranged)
	var high := model.compute_fixed(state, attacker, defender, 1.0, ranged)
	var stack := defender.def as StackDef
	var creature_hp: int = stack.creature_hp if stack != null else defender.def.max_hp
	var top_hp := defender.hp - (count_of(defender) - 1) * creature_hp
	return {
		"min": low,
		"max": high,
		"kills_min": 0 if low < top_hp else 1 + (low - top_hp) / creature_hp,
		"kills_max": 0 if high < top_hp else 1 + (high - top_hp) / creature_hp,
	}
