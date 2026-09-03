class_name DeathCloudRule
extends AreaRule

## The lich's shot: an enemy stack in range is the anchor and everything
## within one cell of it takes the lich's damage, friends included. Spends a
## shot; not usable with an enemy adjacent.


func _init() -> void:
	affects = AFFECTS_ALL


func id() -> String:
	return "death_cloud"


func ends_activation() -> bool:
	return true


func pattern() -> AreaPattern:
	return AreaPattern.radius(1)


func can_use(state: BattleState, unit: BattleUnit) -> bool:
	var rules := state.ruleset as BattlefieldRuleset
	return unit.def.has_tag("cloud") and BattlefieldRuleset.shots_left(unit) > 0 and not rules.has_adjacent_enemy(state, unit)


func anchors(state: BattleState, unit: BattleUnit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for enemy: BattleUnit in state.enemies_on_field_of(unit.faction):
		var d := state.distance_between(unit, enemy)
		if d > 1 and d <= unit.def.range_max:
			result.append(enemy.cell)
	return result


func affect(state: BattleState, engine: BattleEngine, caster: BattleUnit, target: BattleUnit, rng: BattleRng) -> void:
	if target == caster:
		return
	var damage := engine.damage_model.compute(state, caster, target, rng)
	var friendly := not state.ruleset.are_enemies(caster.faction, target.faction)
	target.hp -= maxi(damage, 0)
	engine.emit(state, {
		"type": BattleEvents.ATTACKED,
		"attacker_id": caster.id,
		"defender_id": target.id,
		"damage": maxi(damage, 0),
		"counter": false,
		"ability": id(),
		"friendly": friendly,
		"defender_hp": target.hp,
	})
	if target.hp <= 0:
		engine.kill(state, target, caster.id)


func after_apply(_state: BattleState, _engine: BattleEngine, caster: BattleUnit, _action: BattleAction) -> void:
	caster.custom["shots"] = BattlefieldRuleset.shots_left(caster) - 1


func describe(state: BattleState, action: BattleAction) -> String:
	var anchor: Vector2i = action.params.get("anchor", Vector2i.ZERO)
	var target := state.unit_at(anchor)
	return "Death cloud on %s" % (target.def.display_name if target != null else "(%d,%d)" % [anchor.x, anchor.y])
