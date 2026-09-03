class_name Pathfinder
extends RefCounted

## Reachability for the default MoveRule. Costs come from the ruleset's
## movement_cost, never from the terrain directly; footprints are validated
## at every step; enemies block, allies may be passed through when the ruleset
## allows, and nobody stops on another unit of the same layer.


## Cost for [param mover] to enter the cell configuration anchored at
## [param anchor]: the most expensive footprint cell, or -1 if any cell is
## impassable or out of bounds.
static func step_cost(state: BattleState, mover: BattleUnit, anchor: Vector2i) -> int:
	var worst := 0
	for cell: Vector2i in state.footprint_at(mover, anchor):
		if not state.grid.in_bounds(cell):
			return -1
		var cost := state.ruleset.movement_cost(state, mover, cell)
		if cost < 0:
			return -1
		worst = maxi(worst, cost)
	return worst


## Cells covered by other on-field units on the mover's layer. Built once per
## search: nothing moves during a pathfind.
static func blockers(state: BattleState, mover: BattleUnit) -> Dictionary[Vector2i, BattleUnit]:
	var map: Dictionary[Vector2i, BattleUnit] = {}
	for other: BattleUnit in state.units_on_field():
		if other == mover or other.layer != mover.layer:
			continue
		for cell: Vector2i in state.occupied_cells(other):
			map[cell] = other
	return map


## Can [param mover] pass through the configuration at [param anchor]?
static func can_pass(state: BattleState, mover: BattleUnit, anchor: Vector2i, occupied: Dictionary[Vector2i, BattleUnit] = {}) -> bool:
	if occupied.is_empty():
		occupied = blockers(state, mover)
	for cell: Vector2i in state.footprint_at(mover, anchor):
		var other: BattleUnit = occupied.get(cell)
		if other != null and not state.ruleset.can_pass_through(state, mover, other):
			return false
	return true


## Can [param mover] end a move at [param anchor]?
static func can_stop(state: BattleState, mover: BattleUnit, anchor: Vector2i, occupied: Dictionary[Vector2i, BattleUnit] = {}) -> bool:
	if occupied.is_empty():
		occupied = blockers(state, mover)
	for cell: Vector2i in state.footprint_at(mover, anchor):
		if occupied.has(cell):
			return false
		if not state.ruleset.can_stop_at(state, mover, cell):
			return false
	return true


## Every anchor [param mover] can end a move on within [param budget], mapped
## to {"path": Array[Vector2i] (origin excluded, destination last), "cost": int}.
static func reachable(state: BattleState, mover: BattleUnit, budget: int) -> Dictionary[Vector2i, Dictionary]:
	var best_cost: Dictionary[Vector2i, int] = {mover.cell: 0}
	var paths: Dictionary[Vector2i, Array] = {mover.cell: []}
	var frontier: Array[Vector2i] = [mover.cell]
	var occupied := blockers(state, mover)

	while not frontier.is_empty():
		var cheapest := 0
		for i: int in frontier.size():
			if best_cost[frontier[i]] < best_cost[frontier[cheapest]]:
				cheapest = i
		var current: Vector2i = frontier[cheapest]
		frontier.remove_at(cheapest)
		var current_cost: int = best_cost[current]

		for next: Vector2i in state.grid.neighbors(current):
			var cost := step_cost(state, mover, next)
			if cost < 0:
				continue
			var next_cost := current_cost + cost
			if next_cost > budget:
				continue
			if best_cost.has(next) and best_cost[next] <= next_cost:
				continue
			if not can_pass(state, mover, next, occupied):
				continue
			best_cost[next] = next_cost
			var path: Array[Vector2i] = []
			path.assign(paths[current])
			path.append(next)
			paths[next] = path
			frontier.append(next)

	var result: Dictionary[Vector2i, Dictionary] = {}
	for cell: Vector2i in paths.keys():
		if cell == mover.cell:
			continue
		if not can_stop(state, mover, cell, occupied):
			continue
		var typed_path: Array[Vector2i] = []
		typed_path.assign(paths[cell])
		result[cell] = {"path": typed_path, "cost": best_cost[cell]}
	return result
