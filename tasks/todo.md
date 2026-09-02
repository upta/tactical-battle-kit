# Todo

No lane in flight. Phase 0 (the kit's first cut) closed 2026-09-02: the
node-free core and strategy seams, the headless sim harness with sweeps and
assertions, three example rulesets (square skirmish, chess, hex musket war)
with suites, the debug viewer, two validation scenarios, and the workflow
layer.

## Unplayed, carried

- [ ] Checkpoint 0: Open the viewer, cycle the three examples with N, and
      say whether the debug view is enough to follow a battle or whether the
      first real consumer will need a richer one before it can debug rules.

## Follow-ups

- [ ] Frontier: the attacker AI still draws most games against random play
      once it starves (see `frontier_ai_beats_random`); decide whether that
      is the AI, the map, or the supply numbers, then tighten the assertion.
- [ ] Chess: castling and en passant are omitted; add them if chess is ever
      more than a seam demonstration.
- [ ] A fourth example with a charge-time scheduler (FFT-style) would cover
      the one scheduler shape no example exercises.
