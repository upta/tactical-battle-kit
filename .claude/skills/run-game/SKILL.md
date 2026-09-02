---
name: run-game
description: Use to launch the dev shell's battle viewer and verify it boots and runs clean. Headless with a positive marker for verification, windowed for humans, any example battle by path.
---

# Run the viewer

## Headless boot check (verification)

```powershell
$log = Join-Path $env:TEMP "tbk_boot_verify.log"
$p = Start-Process godot -ArgumentList "--headless", "--path", "src", "--quit-after", "600", "--log-file", $log -Wait -PassThru -WindowStyle Hidden
$p.ExitCode                                                  # must be 0
Select-String -Path $log -Pattern '\[Kit\] Battle ready:'    # MUST appear
Select-String -Path $log -Pattern 'SCRIPT ERROR|ERROR'       # must produce nothing
```

- **Assert the positive marker, don't just count errors:** a boot that dies
  before the battle loads logs no errors at all. The marker is
  `[Kit] Battle ready: <battle_id>`.
- **`--quit-after` + `Start-Process -Wait`, never Stop-Process.** Force-kill
  loses buffered output, the log comes back 0 bytes, the grep finds nothing,
  and it reads as clean. godot.exe is GUI-subsystem: a bare invocation returns
  immediately, so `-Wait` is load-bearing.
- Boot a specific example: add `"--", "--battle", "res://examples/chess/battles/standard.json"`
  to the argument list. The three bundled battles are listed in
  `src/app/battle_viewer.gd`.

## Windowed (humans)

```powershell
godot --path src
godot --path src -- --battle res://examples/frontier/battles/river_crossing.json
```

The viewer opens on a start menu: pick a battle, then "Play <faction>" or
"Watch AI vs AI". `-- --battle <path>` plus `-- --human <faction>` or
`-- --watch` skips the menu. Space steps one AI decision, P pauses the AI, R
restarts the same setup with a new seed, Escape or M returns to the menu.
Playing: click one of
your ringed units, then a highlighted cell (blue: move or act there, yellow:
area anchor) or a red-ringed enemy; targetless actions (wait, entrench, self
heals) and End turn are buttons in the bar. The AI plays its side on a timer
while you think. The status line shows round, side to
act and hp share per faction; the outcome and reason appear when the battle
ends.

## After pulling or switching branches

Re-import before trusting a run; a real boot doesn't auto-import, so a stale
`.godot` cache can silently drop a script:

```powershell
Start-Process godot -ArgumentList "--headless", "--import", "--path", "src" -Wait
```
