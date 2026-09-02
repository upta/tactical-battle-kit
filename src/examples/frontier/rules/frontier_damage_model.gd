class_name FrontierDamageModel
extends LinearDamageModel

## Linear damage shaped by entrenchment, facing, supply and the cannon's
## edge against dug-in troops.

var _rules: FrontierRuleset


func _init(rules: FrontierRuleset) -> void:
	_rules = rules
	variance = 2
	matchup_multipliers = {
		"cavalry>artillery": 2.0,
		"artillery>cavalry": 0.5,
	}


func compute(state: BattleState, attacker: BattleUnit, defender: BattleUnit, rng: BattleRng) -> int:
	var damage := float(super(state, attacker, defender, rng))
	if bool(defender.custom.get("entrenched", false)):
		damage *= 1.5 if attacker.def.has_tag("artillery") else _rules.entrenched_multiplier
	if _rules.is_starving(state, attacker.faction):
		damage *= _rules.starving_damage_multiplier
	var topology := state.grid.topology
	var incoming := topology.direction_to(defender.cell, attacker.cell)
	if defender.facing >= 0 and topology.arc(defender.facing, incoming) >= topology.direction_count() / 2:
		damage *= _rules.rear_multiplier
	return maxi(roundi(damage), min_damage)
