class_name ChessRuleset
extends BattleRuleset

## Chess on the kit: one action per turn, movement enumerated per piece type
## with king safety enforced, checkmate and stalemate as the outcome, no hp,
## no damage model. Castling and en passant are left out on purpose; the
## point is to show a ruleset with no attack, no pathfinder and no movement
## budget still fits the engine. Piece kinds are UnitDef tags.

const PIECE_VALUES: Dictionary[String, int] = {
	"pawn": 1, "knight": 3, "bishop": 3, "rook": 5, "queen": 9, "king": 100,
}
const HALFMOVE_KEY := "halfmove_clock"
const LAST_MOVER_KEY := "last_mover"

var _move_rule := ChessMoveRule.new()
var _defs: Dictionary[String, UnitDef] = {}


func id() -> String:
	return "chess"


func action_rules() -> Array[ActionRule]:
	return [_move_rule]


func activation_slots() -> Array[String]:
	return ["action"]


func max_rounds() -> int:
	return 100


## One move per turn: the turn is over as soon as anything was applied.
func is_turn_over(_state: BattleState, _engine: BattleEngine, turn: BattleTurn) -> bool:
	return turn.actions.size() >= 1


func make_unit_def(data: Dictionary) -> UnitDef:
	var def := super(data)
	_defs[def.id] = def
	return def


func piece_def(piece: String) -> UnitDef:
	return _defs.get(piece)


func check_outcome(state: BattleState) -> BattleOutcome:
	var last_mover := str(state.custom.get(LAST_MOVER_KEY, ""))
	if last_mover.is_empty():
		return null
	if int(state.custom.get(HALFMOVE_KEY, 0)) >= 100:
		return BattleOutcome.draw("fifty_moves")
	var to_move := opponent_of(state, last_mover)
	for piece: BattleUnit in state.units_on_field_of(to_move):
		if not _move_rule.enumerate(state, piece).is_empty():
			return null
	if _move_rule.in_check(state, to_move):
		return BattleOutcome.new(last_mover, "checkmate")
	return BattleOutcome.draw("stalemate")


func summarize(state: BattleState) -> Dictionary:
	var material := {}
	for faction: String in state.factions:
		var total := 0
		for piece: BattleUnit in state.units_on_field_of(faction):
			total += PIECE_VALUES.get(piece_kind(piece), 0)
		material[faction] = total
	return {"material": material, "halfmove_clock": int(state.custom.get(HALFMOVE_KEY, 0))}


func ai_scripts() -> Dictionary[String, GDScript]:
	return {"capture_first": CaptureFirstAi}


static func opponent_of(state: BattleState, faction: String) -> String:
	for other: String in state.factions:
		if other != faction:
			return other
	return ""


static func piece_kind(piece: BattleUnit) -> String:
	for tag: String in piece.def.tags:
		if PIECE_VALUES.has(tag):
			return tag
	return ""
