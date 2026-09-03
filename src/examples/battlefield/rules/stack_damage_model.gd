class_name StackDamageModel
extends DamageModel

## Heroes damage: every creature in the stack rolls its damage range, the
## total is scaled 5% per point of attack over defense (or under), Defend
## adds to defense, and a ranged shot past the penalty distance is halved.

var _rules: BattlefieldRuleset


func _init(rules: BattlefieldRuleset) -> void:
	_rules = rules


func compute(state: BattleState, attacker: BattleUnit, defender: BattleUnit, rng: BattleRng) -> int:
	var ranged := state.distance_between(attacker, defender) > 1
	return compute_fixed(state, attacker, defender, rng.randf(), ranged)


## Deterministic form used by the roll and by tooltips: [param roll] 0..1
## picks the per-creature damage inside the creature's range.
func compute_fixed(state: BattleState, attacker: BattleUnit, defender: BattleUnit, roll: float, ranged: bool) -> int:
	var stack := attacker.def as StackDef
	if stack == null:
		return attacker.def.attack
	var count := BattlefieldRuleset.count_of(attacker)
	var per := stack.damage_min + roundi(float(stack.damage_max - stack.damage_min) * roll)
	var defense := defender.def.defense + (_rules.defend_bonus if bool(defender.custom.get("defending", false)) else 0)
	var multiplier := clampf(1.0 + _rules.attack_defense_step * float(attacker.def.attack - defense), 0.3, 3.0)
	var total := float(count * per) * multiplier
	if ranged and state.distance_between(attacker, defender) > _rules.range_penalty_distance:
		total *= 0.5
	return maxi(roundi(total), 1)
