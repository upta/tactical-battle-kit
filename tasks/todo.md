# Todo

No lane in flight. Phase 1 closed 2026-09-03: the human controller and the
start-menu viewer, web deploys to R2 on every push, the TileMap-backed
presentation contract with `TileMapGridSource`, `ActionTargets` and
`apply_reaction`, and the breach example with hover and shot readouts.

## Unplayed, carried

- [ ] Checkpoint 1: Play a breach game as the squad on the live build. Does
      the cover readout make hits and misses feel fair, and is the AI's
      overwatch legible enough that walking into it reads as your mistake?

## Follow-ups

- [ ] Consume the addon from a fresh project by following
      `.github/skills/install-tactical-battle-kit` end to end; nothing has
      exercised the install path outside this repo yet.
- [ ] A fifth example with a charge-time scheduler, height as a grid layer,
      an oriented area pattern and a 2x2 footprint (FFT-style "plateau")
      would exercise the last seams no example touches.
- [ ] Frontier: the attacker AI still mostly draws against random play once
      it starves (`frontier_ai_beats_random`); decide whether that is the
      AI, the map, or the supply numbers, then tighten the assertion.
- [ ] Chess: castling and en passant are omitted; add them if chess is ever
      more than a seam demonstration.
- [ ] Godot on Linux logs "resources still in use at exit" after the compile
      walk (23 at the time of writing). Find the holder if the count grows.
