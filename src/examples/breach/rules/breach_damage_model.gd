class_name BreachDamageModel
extends DamageModel

## Flat weapon damage with a little spread, and a crit chance against a
## flanked target (no cover toward the shooter).

var _rules: BreachRuleset


func _init(rules: BreachRuleset) -> void:
	_rules = rules


func compute(state: BattleState, attacker: BattleUnit, defender: BattleUnit, rng: BattleRng) -> int:
	var damage := attacker.def.attack + rng.randi_range(-1, 1)
	if _rules.cover_toward(state, defender, attacker.cell) == "none" and rng.chance(float(_rules.flank_crit_chance) / 100.0):
		damage = roundi(float(damage) * 1.5)
	return maxi(damage, 1)
