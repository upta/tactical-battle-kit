---
name: godot-scene-authoring
description: Use when creating or editing a .tscn/.tres, adding a scene script, binding child nodes, or hand-authoring a UnitDef/TerrainDef resource. Text-format mechanics, uid rules, and the scene-first boundaries.
---

# Godot scene and resource authoring

## .tscn text format

- Header: `[gd_scene load_steps=<N> format=3 uid="uid://…"]` where
  `load_steps = ext_resources + sub_resources + 1`. Recount after every edit;
  a wrong count corrupts the load.
- `[ext_resource]` entries carry `type`, `path`, `id`, and usually `uid`.
  `[sub_resource]` entries carry `type` and `id`. Nodes reference them as
  `ExtResource("id")` / `SubResource("id")`.
- `unique_name_in_owner = true` on a node enables `%Name` lookups from scripts
  in the same scene.
- Script properties set in the scene must match `@export` names exactly;
  renaming an export orphans the scene value silently.

## .tres for kit defs

A hand-authored def is a `Resource` with the kit script attached and the
class named in the header so the editor and the loader agree:

```
[gd_resource type="Resource" script_class="UnitDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/tactical_battle_kit/core/unit_def.gd" id="1_unitdef"]

[resource]
script = ExtResource("1_unitdef")
id = "spearman"
tags = Array[String](["infantry", "spear"])
footprint = Array[Vector2i]([Vector2i(0, 0)])
```

- Typed arrays are written `Array[String]([...])`; a plain `[...]` loads as
  untyped and the def's typed field rejects it.
- A subclassed def (`class_name FftUnitDef extends UnitDef`) uses its own
  script path and `script_class`; every kit API accepts it unchanged.
- `id` must be unique within a battle: overrides and sweeps patch by it.

## uid rules

- **Never invent `uid://` values.** Omit the attribute on files you author;
  Godot assigns one on the next import. Preserve existing uids when editing.
- Run the import before committing so every new `.gd` gets its `.uid`
  sidecar, and commit those sidecars with the change:

```powershell
Start-Process godot -ArgumentList "--headless", "--import", "--path", "src" -Wait
git status --porcelain | Select-String '\.uid'   # nothing unstaged
```

## Scene-first rules

- **If a node lives as long as its parent, it is declared in the `.tscn`.**
  `_ready()` does not assemble static structure.
- **Tunables live in a resource or a battle file, not in GDScript literals.**
  A ruleset's tunables are plain vars so `configure()` can sweep them; that
  is the sanctioned exception, and each one is listed in `configure()`.
- **No `load("res://…")` string paths in kit code** except the loader, which
  resolves paths the battle file names; the viewer's `--battle` argument is
  the other sanctioned user.

## Scene errors surface only at runtime

`check_scripts.ps1` loads every `.gd` and `.tscn`, catching a script that will
not compile or a scene that will not load. It does not *run* the scene:
`%UniqueName` lookups, `_ready`, and export wiring surface only on boot. After
a structural `.tscn` change, boot it: the run-game skill headless check, or the
scenario suite if a harness covers it.
