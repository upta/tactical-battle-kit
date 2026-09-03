class_name BreachAi
extends AiController

## Take the best shot; otherwise move to cover facing the nearest enemy,
## dashing only when far; otherwise overwatch if anyone could come at you,
## hunker when hurt. One ply, an example.


func id() -> String:
	return "breach"


func choose(state: BattleState, engine: BattleEngine, turn: BattleTurn, _rng: BattleRng) -> BattleAction:
	var best: BattleAction = null
	var best_score := -INF
	for action: BattleAction in engine.legal_actions(state, turn):
		var score := _score(state, action)
		if score > best_score:
			best_score = score
			best = action
	return best


func _score(state: BattleState, action: BattleAction) -> float:
	var rules := state.ruleset as BreachRuleset
	var unit := state.unit(action.unit_id)
	var enemies := state.enemies_on_field_of(unit.faction)
	match action.kind:
		"shoot":
			var target := state.unit(action.target_unit_id())
			var chance := float(rules.hit_chance(state, unit, target))
			var lethal := 25.0 if target.hp <= unit.def.attack else 0.0
			return 100.0 + chance + lethal
		"move":
			var cell := action.target_cell()
			var nearest := _nearest(state, enemies, cell)
			var cover := rules.cover_toward(state, _phantom(unit, cell), nearest.cell if nearest != null else cell)
			var cover_score := 30.0 if cover == "full" else (15.0 if cover == "half" else 0.0)
			var distance := state.grid.distance(cell, nearest.cell) if nearest != null else 0
			# Close to mid range rather than sitting at maximum range: a
			# stand-off at max range through cover is a fifteen-round draw.
			var range_fit := -absf(float(distance) - float(unit.def.range_max - 3)) * 3.0
			var dash_penalty := -10.0 if int(action.params.get("cost", 0)) > unit.def.move else 0.0
			return 40.0 + cover_score + range_fit + dash_penalty
		"overwatch":
			var in_cover := rules.cover_toward(state, unit, _nearest(state, enemies, unit.cell).cell if not enemies.is_empty() else unit.cell) != "none"
			var threatened := false
			for enemy: BattleUnit in enemies:
				if state.grid.distance(unit.cell, enemy.cell) <= enemy.def.move + unit.def.range_max:
					threatened = true
			return 45.0 if threatened and in_cover else 8.0
		"hunker":
			return 50.0 if unit.hp_fraction() < 0.5 else 2.0
	return 0.0


func _nearest(state: BattleState, enemies: Array[BattleUnit], from: Vector2i) -> BattleUnit:
	var best: BattleUnit = null
	var best_distance := 99
	for enemy: BattleUnit in enemies:
		var d := state.grid.distance(from, enemy.cell)
		if d < best_distance:
			best_distance = d
			best = enemy
	return best


## A throwaway copy of the unit standing at [param cell], for cover checks.
func _phantom(unit: BattleUnit, cell: Vector2i) -> BattleUnit:
	var copy := unit.clone()
	copy.cell = cell
	return copy
