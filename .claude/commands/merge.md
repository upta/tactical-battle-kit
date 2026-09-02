# /merge

Land the branch on main, fast-forward only.

- Pre-flight: clean tree, /ship said GO, main freshly fetched.
- `git switch main && git merge --ff-only <branch> && git push origin main`
- Delete with `git branch -d` (not `-D`): it refuses to delete anything
  unmerged, which makes it a second check that the merge actually landed.
  Delete the remote branch too.
- Pushing main triggers CI only (compile, lint, and the headless sim suites).
  Nothing deploys; the kit is consumed as a submodule, so consumers move
  their gitlink when they choose to.
- The phase ticket (`tasks/phase-<N>.md`) is deleted when the phase closes,
  which is not necessarily the moment the branch merges; a branch can carry
  several phases.
