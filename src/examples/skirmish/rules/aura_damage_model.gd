class_name AuraDamageModel
extends LinearDamageModel

## Linear damage plus the commander aura and a rear-attack bonus read off
## facing. The matchup triangle lives here as data.

var _rules: SkirmishRuleset


func _init(rules: SkirmishRuleset) -> void:
	_rules = rules
	matchup_multipliers = {
		"spear>cavalry": 1.5,
		"cavalry>archer": 1.5,
		"archer>spear": 1.25,
	}


func compute(state: BattleState, attacker: BattleUnit, defender: BattleUnit, rng: BattleRng) -> int:
	var damage := super(state, attacker, defender, rng)
	if _rules.in_aura(state, attacker):
		damage += _rules.aura_bonus
	var topology := state.grid.topology
	var incoming := topology.direction_to(defender.cell, attacker.cell)
	if defender.facing >= 0 and topology.arc(defender.facing, incoming) >= topology.direction_count() / 2:
		damage = roundi(float(damage) * _rules.rear_multiplier)
	return maxi(damage, min_damage)
