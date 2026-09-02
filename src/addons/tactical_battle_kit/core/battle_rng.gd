class_name BattleRng
extends RefCounted

## Seeded randomness with named sub-streams. Every roll in a battle goes
## through one of these so a seed replays the same battle exactly, and forking
## per purpose ("engine", "ai:red") keeps one consumer's extra rolls from
## shifting another's.

var seed_value: int = 0
var _rng := RandomNumberGenerator.new()


func _init(initial_seed: int = 0) -> void:
	seed_value = initial_seed
	_rng.seed = initial_seed


func fork(label: String) -> BattleRng:
	return BattleRng.new(hash([seed_value, label]))


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()


func chance(probability: float) -> bool:
	return _rng.randf() < probability


func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


func shuffle(items: Array) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
