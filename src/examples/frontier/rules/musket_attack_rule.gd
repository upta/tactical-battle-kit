class_name MusketAttackRule
extends AttackRule

## Volleys: no counterattack, ranged units need gunpowder and spend one per
## shot, and a defender left under the rout threshold breaks: captured if an
## enemy stands adjacent, routed otherwise.


func _init() -> void:
	counterattacks = false


func can_use(_state: BattleState, unit: BattleUnit) -> bool:
	if unit.def.has_tag("ranged"):
		return int(unit.custom.get("powder", 0)) > 0
	return true


## Cannon cannot fire point blank; the def's range_min carries that. Rear
## and flank shots need no line of sight in this ruleset.
func can_target(_state: BattleState, _attacker: BattleUnit, _defender: BattleUnit) -> bool:
	return true


func after_attack(state: BattleState, engine: BattleEngine, attacker: BattleUnit, defender: BattleUnit) -> void:
	if attacker.def.has_tag("ranged"):
		attacker.custom["powder"] = int(attacker.custom.get("powder", 0)) - 1
	if not defender.is_on_field():
		return
	var rules := state.ruleset as FrontierRuleset
	var threshold := rules.starving_rout_threshold if rules.is_starving(state, defender.faction) else rules.rout_threshold
	if defender.hp_fraction() >= threshold:
		return
	var status := "routed"
	for neighbor: Vector2i in state.grid.neighbors(defender.cell):
		var adjacent := state.unit_at(neighbor)
		if adjacent != null and state.ruleset.are_enemies(defender.faction, adjacent.faction):
			status = "captured"
			break
	engine.remove_from_field(state, defender, status, attacker.id)
