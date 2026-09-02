class_name BattleOutcome
extends RefCounted

## A decided battle. [member winner] is a faction id, or "" for a draw.

var winner: String = ""
var reason: String = ""


func _init(winning_faction: String = "", why: String = "") -> void:
	winner = winning_faction
	reason = why


static func draw(why: String) -> BattleOutcome:
	return BattleOutcome.new("", why)


func is_draw() -> bool:
	return winner.is_empty()


func to_dict() -> Dictionary:
	return {"winner": winner, "reason": reason}
