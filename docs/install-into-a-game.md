# Install into a game

The addon is `src/addons/tactical_battle_kit/`. Nothing else in this
repository is required by a consumer; the examples, viewer, suites and
scenarios are this repo's own proof.

## As a submodule (recommended)

```
git submodule add https://github.com/upta/tactical-battle-kit.git submodules/tactical_battle_kit
```

Then link `<project>/addons/tactical_battle_kit` to
`submodules/tactical_battle_kit/src/addons/tactical_battle_kit`:

```
cmd /c "mklink /D addons\tactical_battle_kit ..\submodules\tactical_battle_kit\src\addons\tactical_battle_kit"   # Windows
ln -s ../submodules/tactical_battle_kit/src/addons/tactical_battle_kit addons/tactical_battle_kit          # Linux, macOS
```

(The sibling repos do this with a `symlink-config.txt` and
`setup.ps1`/`setup.sh`; copy those if the project has none.) Kit improvements then flow by moving the
gitlink.

## As a copy

Copy `src/addons/tactical_battle_kit/` into the project's `addons/`. Enable
the plugin in Project Settings or leave it disabled; the kit registers no
editor UI and its classes are available either way.

## First battle

Import once before any headless run (`godot --headless --import --path .`):
a fresh project has no class cache and every kit `class_name` is undeclared
until then. Create `artifacts/.gdignore` so reports are never scanned.

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

## The finished result

`example-game/` in the kit repository is a consuming project laid out this
way: `rules/outpost_ruleset.gd`, `ai/garrison_ai.gd` registered through
`ai_scripts()`, `battles/outpost.json` naming both, and `sim/suites/` with a
smoke suite and one that proves the game's own AI is the one playing. Its
suites run in the kit's CI from that project, so the path above is exercised
on every push. Copy its shape; nothing in it is test-only.

## Skills

Copy or symlink `.github/skills/author-battle-ruleset` and
`.github/skills/run-balance-sim` into the project's `.claude/skills/` so an
agent working in the game has the seam table and the suite schema.

## Requirements

Godot 4.5 or newer (the kit uses `@abstract` and typed dictionaries);
developed and validated on 4.7.1. No autoloads, no editor plugin
dependencies, no C#.
