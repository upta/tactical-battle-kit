class_name SkirmishRuleset
extends BattleRuleset

## Warsong-flavored skirmish: commanders lead mercenaries, an aura buffs
## troops near their commander, troops dissolve when their commander falls,
## counterattacks are full strength, cavalry cannot enter forest, and facing
## matters. Exercises hooks, custom outcome, a template attack rule, an area
## rule, configure/summarize, and a game-registered AI.

var aura_range: int = 3
var aura_bonus: int = 2
var heal_amount: int = 3
var rear_multiplier: float = 1.5


func id() -> String:
	return "skirmish"


func action_rules() -> Array[ActionRule]:
	var heal := HealAuraRule.new()
	heal.amount = heal_amount
	return [MoveRule.new(), CommanderAttackRule.new(), heal, WaitRule.new()]


func damage_model() -> DamageModel:
	return AuraDamageModel.new(self)


func uses_facing() -> bool:
	return true


func max_rounds() -> int:
	return 40


func movement_cost(state: BattleState, unit: BattleUnit, cell: Vector2i) -> int:
	if unit.def.has_tag("cavalry") and state.grid.has_tag_at(cell, "forest"):
		return -1
	return super(state, unit, cell)


func check_outcome(state: BattleState) -> BattleOutcome:
	for faction: String in state.factions:
		if had_commander(state, faction) and commanders_on_field(state, faction).is_empty():
			var others := state.factions.filter(func(f: String) -> bool: return f != faction)
			return BattleOutcome.new(others[0] if others.size() == 1 else "", "commander_fell")
	return super(state)


func on_event(state: BattleState, engine: BattleEngine, event: Dictionary) -> void:
	if str(event.get("type")) != BattleEvents.UNIT_DIED:
		return
	var fallen := state.unit(str(event.get("unit_id")))
	if fallen == null or not fallen.def.has_tag("commander"):
		return
	for unit: BattleUnit in state.units_on_field_of(fallen.faction):
		if str(unit.custom.get("commander", "")) == fallen.id:
			engine.remove_from_field(state, unit, "dissolved", fallen.id)


func configure(params: Dictionary) -> void:
	aura_range = int(params.get("aura_range", aura_range))
	aura_bonus = int(params.get("aura_bonus", aura_bonus))
	heal_amount = int(params.get("heal_amount", heal_amount))
	rear_multiplier = float(params.get("rear_multiplier", rear_multiplier))


func summarize(state: BattleState) -> Dictionary:
	var dissolved := {}
	for faction: String in state.factions:
		dissolved[faction] = 0
	for unit: BattleUnit in state.units.values():
		if unit.status == "dissolved":
			dissolved[unit.faction] = int(dissolved.get(unit.faction, 0)) + 1
	return {"dissolved": dissolved}


func ai_scripts() -> Dictionary[String, GDScript]:
	return {"greedy": GreedyAi}


# --- Helpers the rules and AI share ---


func had_commander(state: BattleState, faction: String) -> bool:
	for unit: BattleUnit in state.units_of(faction):
		if unit.def.has_tag("commander"):
			return true
	return false


func commanders_on_field(state: BattleState, faction: String) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit: BattleUnit in state.units_on_field_of(faction):
		if unit.def.has_tag("commander"):
			result.append(unit)
	return result


func in_aura(state: BattleState, unit: BattleUnit) -> bool:
	var commander := state.unit(str(unit.custom.get("commander", "")))
	if commander == null or not commander.is_on_field():
		return false
	return state.distance_between(unit, commander) <= aura_range
