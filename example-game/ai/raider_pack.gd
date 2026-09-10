extends RefCounted

## An AI pack: names AIs that the ruleset does not ship. A suite lists this
## script under "register" (or the CLI gets --register) and the static
## register() runs before any battle is built.


static func register() -> void:
	AiRegistry.register("rush", RushAi)
