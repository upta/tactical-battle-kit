class_name OutpostRuleset
extends BattleRuleset

## The example game's rules: a garrison holds a walled outpost against
## raiders. Kit defaults for everything (faction turns, move then attack,
## linear damage with terrain defense) plus one custom metric so the suites
## show how a game measures its own question, not only who won.


func id() -> String:
	return "outpost"


func action_rules() -> Array[ActionRule]:
	return [MoveRule.new(), AttackRule.new(), WaitRule.new()]


func max_rounds() -> int:
	return 30


## How many garrison units ended the battle standing on a wall cell. A
## numeric leaf here is averaged across runs and reachable from a suite
## as custom.walls_held.
func summarize(state: BattleState) -> Dictionary:
	var held := 0
	for unit: BattleUnit in state.units_on_field_of("garrison"):
		if state.grid.has_tag_at(unit.cell, "cover"):
			held += 1
	return {"walls_held": held}


func ai_scripts() -> Dictionary[String, GDScript]:
	return {"garrison": GarrisonAi}
