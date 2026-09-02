class_name ChessMoveRule
extends ActionRule

## Every chess move is this one rule: enumerate() lists pseudo-legal moves per
## piece kind and keeps the ones that leave the mover's king safe; apply()
## moves, captures through engine.kill(), promotes pawns to queens, and keeps
## the halfmove clock. King safety is tested by ray-casting from the king,
## never by cloning the state, so a full move list costs microseconds.

const _ROOK_RAYS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const _BISHOP_RAYS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const _KNIGHT_JUMPS: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
	Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1),
]


func id() -> String:
	return "chess_move"


func enumerate(state: BattleState, piece: BattleUnit) -> Array[BattleAction]:
	var actions: Array[BattleAction] = []
	for target: Vector2i in pseudo_moves(state, piece):
		if leaves_king_safe(state, piece, target):
			var captured := state.unit_at(target)
			actions.append(make_action(piece, {
				"target_cell": target,
				"captures": captured.id if captured != null else "",
			}))
	return actions


func apply(state: BattleState, engine: BattleEngine, action: BattleAction, _rng: BattleRng) -> void:
	var piece := state.unit(action.unit_id)
	var origin := piece.cell
	var target := action.target_cell()
	var captured := state.unit_at(target)
	var kind := ChessRuleset.piece_kind(piece)
	var resets_clock := captured != null or kind == "pawn"

	if captured != null:
		captured.hp = 0
		engine.kill(state, captured, piece.id)
	piece.cell = target
	piece.custom["moved"] = true

	var promoted := false
	if kind == "pawn" and (target.y == 0 or target.y == state.grid.height - 1):
		var queen := (state.ruleset as ChessRuleset).piece_def("queen")
		if queen != null:
			piece.def = queen
			promoted = true

	var clock := int(state.custom.get(ChessRuleset.HALFMOVE_KEY, 0))
	state.custom[ChessRuleset.HALFMOVE_KEY] = 0 if resets_clock else clock + 1
	state.custom[ChessRuleset.LAST_MOVER_KEY] = piece.faction

	engine.emit(state, {
		"type": BattleEvents.MOVED,
		"unit_id": piece.id,
		"from": BattleEvents.cell(origin),
		"to": BattleEvents.cell(target),
		"path": [BattleEvents.cell(target)],
		"cost": 1,
		"interrupted": false,
		"captured": captured.id if captured != null else "",
		"promoted": promoted,
	})


func describe(state: BattleState, action: BattleAction) -> String:
	var target := action.target_cell()
	var captures := str(action.params.get("captures", ""))
	var suffix := " taking %s" % captures if not captures.is_empty() else ""
	return "%s to %s%s" % [action.unit_id, square_name(state, target), suffix]


# --- Move generation ---


func pseudo_moves(state: BattleState, piece: BattleUnit) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var grid := state.grid
	match ChessRuleset.piece_kind(piece):
		"pawn":
			var forward := Vector2i(0, -1) if piece.faction == "white" else Vector2i(0, 1)
			var one := piece.cell + forward
			if grid.in_bounds(one) and state.unit_at(one) == null:
				moves.append(one)
				var start_row := grid.height - 2 if piece.faction == "white" else 1
				var two := one + forward
				if piece.cell.y == start_row and grid.in_bounds(two) and state.unit_at(two) == null:
					moves.append(two)
			for dx: int in [-1, 1]:
				var diagonal := piece.cell + forward + Vector2i(dx, 0)
				var victim := state.unit_at(diagonal) if grid.in_bounds(diagonal) else null
				if victim != null and victim.faction != piece.faction:
					moves.append(diagonal)
		"knight":
			for jump: Vector2i in _KNIGHT_JUMPS:
				_add_step(state, piece, piece.cell + jump, moves)
		"bishop":
			_add_rays(state, piece, _BISHOP_RAYS, moves)
		"rook":
			_add_rays(state, piece, _ROOK_RAYS, moves)
		"queen":
			_add_rays(state, piece, _ROOK_RAYS, moves)
			_add_rays(state, piece, _BISHOP_RAYS, moves)
		"king":
			for ray: Vector2i in _ROOK_RAYS:
				_add_step(state, piece, piece.cell + ray, moves)
			for ray: Vector2i in _BISHOP_RAYS:
				_add_step(state, piece, piece.cell + ray, moves)
	return moves


func _add_step(state: BattleState, piece: BattleUnit, target: Vector2i, moves: Array[Vector2i]) -> void:
	if not state.grid.in_bounds(target):
		return
	var occupant := state.unit_at(target)
	if occupant == null or occupant.faction != piece.faction:
		moves.append(target)


func _add_rays(state: BattleState, piece: BattleUnit, rays: Array[Vector2i], moves: Array[Vector2i]) -> void:
	for ray: Vector2i in rays:
		var cursor := piece.cell + ray
		while state.grid.in_bounds(cursor):
			var occupant := state.unit_at(cursor)
			if occupant == null:
				moves.append(cursor)
			else:
				if occupant.faction != piece.faction:
					moves.append(cursor)
				break
			cursor += ray


# --- King safety ---


func leaves_king_safe(state: BattleState, piece: BattleUnit, target: Vector2i) -> bool:
	var origin := piece.cell
	var captured := state.unit_at(target)
	var captured_status := captured.status if captured != null else ""
	if captured != null:
		captured.status = "pending_capture"
	piece.cell = target
	var safe := not in_check(state, piece.faction)
	piece.cell = origin
	if captured != null:
		captured.status = captured_status
	return safe


func in_check(state: BattleState, faction: String) -> bool:
	for piece: BattleUnit in state.units_on_field_of(faction):
		if ChessRuleset.piece_kind(piece) == "king":
			return is_attacked(state, piece.cell, ChessRuleset.opponent_of(state, faction))
	return false


## Is [param cell] attacked by any on-field piece of [param by]? Rays cast
## outward from the cell, so the cost does not depend on how many pieces
## the attacker has.
func is_attacked(state: BattleState, cell: Vector2i, by: String) -> bool:
	var grid := state.grid
	for jump: Vector2i in _KNIGHT_JUMPS:
		var piece := state.unit_at(cell + jump) if grid.in_bounds(cell + jump) else null
		if piece != null and piece.faction == by and ChessRuleset.piece_kind(piece) == "knight":
			return true
	var pawn_forward := Vector2i(0, -1) if by == "white" else Vector2i(0, 1)
	for dx: int in [-1, 1]:
		var from := cell - pawn_forward + Vector2i(dx, 0)
		var piece := state.unit_at(from) if grid.in_bounds(from) else null
		if piece != null and piece.faction == by and ChessRuleset.piece_kind(piece) == "pawn":
			return true
	for ray: Vector2i in _ROOK_RAYS:
		if _ray_hits(state, cell, ray, by, ["rook", "queen"], true):
			return true
	for ray: Vector2i in _BISHOP_RAYS:
		if _ray_hits(state, cell, ray, by, ["bishop", "queen"], true):
			return true
	return false


func _ray_hits(state: BattleState, cell: Vector2i, ray: Vector2i, by: String, kinds: Array[String], king_adjacent: bool) -> bool:
	var cursor := cell + ray
	var steps := 1
	while state.grid.in_bounds(cursor):
		var piece := state.unit_at(cursor)
		if piece != null:
			if piece.faction != by:
				return false
			var kind := ChessRuleset.piece_kind(piece)
			if kinds.has(kind):
				return true
			return king_adjacent and steps == 1 and kind == "king"
		cursor += ray
		steps += 1
	return false


static func square_name(state: BattleState, cell: Vector2i) -> String:
	return "%s%d" % [char("a".unicode_at(0) + cell.x), state.grid.height - cell.y]
