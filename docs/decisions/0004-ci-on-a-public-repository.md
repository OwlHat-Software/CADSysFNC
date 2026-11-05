# 0004 - CI, given that this repository is public

**Status:** Accepted
**Date:** 2026-11-05
**Links:** -

## Question
Section 7 of Masterplanner's workflow has CI build every push on a self-hosted runner. The other repositories can do
that because they are private: their `build.yml` says the repository "must stay PRIVATE", since a self-hosted runner
executes whatever code is pushed to it. `OwlHat-Software/CADSysFNC` is public (checked 2026-11-05). It has had no CI
since 6bdcc89 (2026-09-21), which retired the upstream workflow because it could not reach TMS FNC.

The laptop's runner `OHS-LAPTOP-001` is registered for the organisation and runs as `ghrunner`, which can read
`delphi_libraries`, TMS's licensed sources included. Whether its runner group admits public repositories was not
checked: that takes organisation admin rights.

## Options
| Option | For | Against |
|---|---|---|
| A. No CI. `build.cmd` in the main folder is the gate; push on request | Nothing exposed, nothing to set up; the applications read this folder, and their own CI builds against it | Nothing checks a clean checkout, so a file that was not added goes unnoticed until someone clones; no results to read from a phone |
| B. The self-hosted runner, on pushes to `master` and by hand only, with no `pull_request` trigger | Same gate as the other repositories; a clean checkout on every push; forks cannot start it | GitHub advises against self-hosted runners on public repositories; the runner group has to admit public repositories; run logs and artifacts are public and show local paths; a mistake in the trigger gives strangers code execution on the laptop |
| C. Make the repository private, then as the other repositories | Same set-up everywhere; safe | The README presents an open MIT library with a public clone URL, and that would end |
| D. A hosted runner, for what needs no Delphi (`check-comments.py`, `gen-units.ps1`) | Safe and free on a public repository | Compiles nothing: TMS FNC is licensed and not available there. Little value for a job to look after |

## Recommendation
A. The two things CI would add are worth less here than in the other repositories, because the applications already
compile this folder, and B's risk falls on the laptop that holds everything else. The one real gap, a file that was not
added, is covered by checking `git status` before a commit and by building a clean clone before a push that matters.

## Decision
Option A, chosen by Jacco Uijlenhoet on 2026-11-05: no CI, `build.cmd` in the main folder is the gate, push on request.

## Consequences
- No workflow file is added. Push on request; report "no CI" rather than a CI result.
- Check `git status` before a commit, and build a clean clone before a push that matters, because nothing else notices
  a file that was not added.
- No self-hosted runner on this repository without a new decision that amends this one.
