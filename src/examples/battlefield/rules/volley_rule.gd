class_name VolleyRule
extends AttackRule

## A ranged stack shoots any enemy in range while it has shots and no enemy
## stands adjacent; no retaliation. Distance halves damage through the
## damage model.


func _init() -> void:
	counterattacks = false
	attack_ends_activation = true


func id() -> String:
	return "volley"


func can_use(state: BattleState, unit: BattleUnit) -> bool:
	var rules := state.ruleset as BattlefieldRuleset
	return BattlefieldRuleset.shots_left(unit) > 0 and not rules.has_adjacent_enemy(state, unit) and not unit.def.has_tag("cloud")


func in_range(state: BattleState, attacker: BattleUnit, defender: BattleUnit) -> bool:
	var d := state.distance_between(attacker, defender)
	return d > 1 and d <= attacker.def.range_max


func after_attack(_state: BattleState, _engine: BattleEngine, attacker: BattleUnit, _defender: BattleUnit) -> void:
	attacker.custom["shots"] = BattlefieldRuleset.shots_left(attacker) - 1


func describe(state: BattleState, action: BattleAction) -> String:
	var attacker := state.unit(action.unit_id)
	var target := state.unit(action.target_unit_id())
	if attacker == null or target == null:
		return "%s shoots" % action.unit_id
	var expected: Dictionary = (state.ruleset as BattlefieldRuleset).expected_damage(state, attacker, target, true)
	return "Shoot %s (%d-%d dmg)" % [target.def.display_name, int(expected["min"]), int(expected["max"])]
