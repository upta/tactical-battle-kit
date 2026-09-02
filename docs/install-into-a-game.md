# Install into a game

The addon is `src/addons/tactical_battle_kit/`. Nothing else in this
repository is required by a consumer; the examples, viewer, suites and
scenarios are this repo's own proof.

## As a submodule (recommended)

```
git submodule add https://github.com/upta/tactical-battle-kit.git submodules/tactical_battle_kit
```

Then symlink `<project>/addons/tactical_battle_kit` to
`submodules/tactical_battle_kit/src/addons/tactical_battle_kit` (the sibling
repos do this with a `symlink-config.txt` and `setup.ps1`/`setup.sh`; copy
those if the project has none). Kit improvements then flow by moving the
gitlink.

## As a copy

Copy `src/addons/tactical_battle_kit/` into the project's `addons/`. Enable
the plugin in Project Settings or leave it disabled; the kit registers no
editor UI and its classes are available either way.

## First battle

1. Write a `BattleRuleset` subclass (`docs/write-a-ruleset.md`).
2. Write a battle file (`docs/battle-file.md`), naming that script.
3. In a scene: a `BattleView` (debug) or the game's own view, a
   `BattleRunner` node, and

```gdscript
var state := BattleLoader.load_file("res://battles/first.json")
$BattleRunner.setup(state, {}, seed_value)
$BattleView.state = state
await $BattleRunner.step()
```

4. Headless: `BattleSimulator.new().run(state, ais, BattleRng.new(seed))`, or
   a suite JSON and the sim CLI (`docs/write-a-sim-suite.md`).

## Skills

Copy or symlink `.github/skills/author-battle-ruleset` and
`.github/skills/run-balance-sim` into the project's `.claude/skills/` so an
agent working in the game has the seam table and the suite schema.

## Requirements

Godot 4.5 or newer (the kit uses `@abstract` and typed dictionaries);
developed and validated on 4.7.1. No autoloads, no editor plugin
dependencies, no C#.
