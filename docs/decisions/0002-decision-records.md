# 0002 - Choices are recorded as decision records

**Status:** Accepted
**Date:** 2026-11-05
**Links:** -

## Question
Where do the choices the developer makes get written down, so a later session does not reopen them or build on one that
was never made?

## Options
| Option | For | Against |
|---|---|---|
| A. One record per choice in `docs\decisions`, as in section 4 of the workflow | Can be found again, with the options that were turned down; the same in every repository | A file for every choice |
| B. In commit messages and the spec | No extra files | Hard to find; a proposal has no place to wait for an answer |

## Recommendation
A.

## Decision
Option A, adopted by Jacco Uijlenhoet with the workflow (0001), 2026-11-05.

## Consequences
- Nothing is built on a record with status *Proposed*.
- `docs\decisions\README.md` keeps the index.
