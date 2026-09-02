class_name HealAuraRule
extends AreaRule

## A commander spends its action to heal every ally within two cells.

var amount: int = 3


func _init() -> void:
	cast_range = 0
	affects = AFFECTS_ALLIES


func id() -> String:
	return "heal_aura"


func can_use(_state: BattleState, unit: BattleUnit) -> bool:
	return unit.def.has_tag("commander")


func pattern() -> AreaPattern:
	return AreaPattern.radius(2)


func affect(state: BattleState, engine: BattleEngine, caster: BattleUnit, target: BattleUnit, _rng: BattleRng) -> void:
	if target.hp < target.def.max_hp:
		heal(state, engine, caster, target, amount)


func describe(_state: BattleState, action: BattleAction) -> String:
	return "%s rallies nearby troops" % action.unit_id
