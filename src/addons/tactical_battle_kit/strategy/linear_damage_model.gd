class_name LinearDamageModel
extends DamageModel

## attack * matchup - defense * (1 + terrain defense bonus) + jitter, floored
## at min_damage. Matchups are keyed "attacker_tag>defender_tag" and multiply
## together when several apply.

var min_damage: int = 1
## Uniform jitter in [-variance, +variance] hit points.
var variance: int = 1
var matchup_multipliers: Dictionary[String, float] = {}


func compute(state: BattleState, attacker: BattleUnit, defender: BattleUnit, rng: BattleRng) -> int:
	var multiplier := 1.0
	for attacker_tag: String in attacker.def.tags:
		for defender_tag: String in defender.def.tags:
			multiplier *= matchup_multipliers.get("%s>%s" % [attacker_tag, defender_tag], 1.0)
	var terrain_bonus := 0.0
	for terrain: TerrainDef in state.grid.terrain_stack(defender.cell):
		terrain_bonus += terrain.defense_bonus
	var base := float(attacker.def.attack) * multiplier - float(defender.def.defense) * (1.0 + terrain_bonus)
	var jitter := rng.randi_range(-variance, variance) if variance > 0 else 0
	return maxi(roundi(base) + jitter, min_damage)
