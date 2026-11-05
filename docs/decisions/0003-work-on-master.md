# 0003 - Work and build in the main folder, on master

**Status:** Accepted
**Date:** 2026-11-05
**Links:** -

## Question
Where does Claude work? Masterplanner and VisualPlannerFNC compile against `Generated\FMX` in this folder, and their CI
reads it as it is on disk (VisualPlannerFNC's decision 0006), so what is in this folder is what they get.

## Options
| Option | For | Against |
|---|---|---|
| A. In the project folder itself, on `master`; `build.cmd` there | The applications always get the latest library; compile errors in them show at once | No review per change before it is on `master`; a half-finished change in this folder reaches the applications' next build |
| B. `claude/<topic>` branches in worktrees, with a pull request per change | Isolated; review before merge | `Generated\` here lags until a merge; more steps per change |

## Recommendation
A, as section 3 of the workflow says. Risky work can still go on a branch when Jacco asks.

## Decision
Option A, adopted by Jacco Uijlenhoet with the workflow (0001), 2026-11-05.

## Consequences
- A session should be started on the folder itself, not in a worktree.
- A session started in a worktree anyway edits and commits there, then moves `master` to the result and runs `build.cmd`
  in the main folder. A worktree needs `CADSYS_TMS` set to build at all.
- Pushing is separate: see 0004.
