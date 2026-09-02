# /merge

Land the branch on main, fast-forward only.

- Pre-flight: clean tree, /ship said GO, main freshly fetched.
- `git switch main && git merge --ff-only <branch> && git push origin main`
- Delete with `git branch -d` (not `-D`): it refuses to delete anything
  unmerged, which makes it a second check that the merge actually landed.
  Delete the remote branch too. This is cleanup, not tidiness: the deletion
  fires `.github/workflows/playtest-cleanup.yml`, which prunes the branch's
  ~40 MiB playtest build from R2. Confirm the prune run went green.
- Pushing main triggers CI (compile and the headless sim suites) and the
  playtest deploy: the main web build at
  `<R2_PUBLIC_BASE>/tactical-battle-kit/main/index.html` is replaced. Say so
  when you ask for the go-ahead.
- The phase ticket (`tasks/phase-<N>.md`) is deleted when the phase closes,
  which is not necessarily the moment the branch merges; a branch can carry
  several phases.
