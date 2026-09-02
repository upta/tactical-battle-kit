# /review

Cheap mid-phase review, single pass, current diff or named files.

- Follow `.claude/agents/code-reviewer.md`, including its instruction to read
  ARCHITECTURE.md and CLAUDE.md first; this repo has opinions that look wrong
  under generic Godot defaults.
- Findings graded Critical / Important / Suggestion with `file:line`.
- Fix Criticals now; Importants now or as todo.md entries; Suggestions only if
  trivial.
- Don't run this AND /ship at a phase boundary; /ship includes the review.
