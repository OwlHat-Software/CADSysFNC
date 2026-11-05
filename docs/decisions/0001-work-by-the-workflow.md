# 0001 - Work as described in the workflow

**Status:** Accepted
**Date:** 2026-11-05
**Links:** -

## Question
Masterplanner, VisualPlannerFNC and vpplocalprovider work by `docs\claude-workflow.md`. Does this library, and in what
form? It has no program of its own, no requirements document, and it is public.

## Options
| Option | For | Against |
|---|---|---|
| A. The same workflow, adapted to a library | One way of working across the repositories | Parts do not apply and have to be left out |
| B. Carry on without one | Nothing to set up | The gate, the place of the plan and the rules stay in people's heads |

## Recommendation
A.

## Decision
Option A, asked for by Jacco Uijlenhoet on 2026-11-05. The developer decides and Claude implements (section 1).
`docs\masterplanner-changes.md` takes the place of the requirements and the implementation plan (section 2).

## Consequences
- Section 10 of the workflow lists what was left out and why.
- `CLAUDE.md` is the short version; the two change together.
