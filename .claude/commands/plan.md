# /plan

Write the next phase ticket. Read-only for the codebase: no code changes.

- One file: `tasks/phase-<N>.md`, ~40 lines. One phase in flight at a time
  per lane; a third `phase-*.md` is an error the docs hook enforces.
- Every task is a vertical slice someone can feel: a game author can express
  a rule they could not before, a suite answers a balance question it could
  not before, a scenario proves something on screen. A task that only adds a
  class is not a slice.
- Acceptance = named proof: which sim suite or scenario, what it drives, what
  it asserts, and what would prove it RED. If you cannot name the proof, the
  task is not planned yet.
- If a task is a major change (CLAUDE.md § No silent architecture), the
  ticket says so and names the seam it adds or changes; the proposal itself
  happens at /build time.
- Format:

```markdown
# Phase <N>: <name>
**Goal:** <2-3 sentences>

## Task <N>.1: <name>
<1-2 sentences.>
- Acceptance: `<suite_or_scenario>` — <drives / asserts / what proves it RED>
- Files: <the seams this touches (ARCHITECTURE.md names them)>
- Major: <no | yes: which seam>

## Checkpoint <N> (HUMAN)
- [ ] <the question a human answers by playing the viewer or reading a report>
```

- Reset `tasks/todo.md` to the new checklist; the final item is the human
  checkpoint.
- Stop for approval before /build.
