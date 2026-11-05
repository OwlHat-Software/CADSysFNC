# 0005 - TMS WEB Core support: target, unit names, core data, fonts, first user

**Status:** Accepted
**Date:** 2026-11-05
**Links:** `docs\web\implementation-plan.md`

## Question
How should CADSysFNC run on TMS WEB Core? The plan in `docs\web\implementation-plan.md` left five choices open: how
far to go, what the WEB units are called, where the pointer-free core data lives, how the vector fonts get to the
browser, and what shows it first.

## Options
| Option | For | Against |
|---|---|---|
| 1A. Viewer only (phases 0 to 3, SVG and PDF from phase 5) | 3.5 to 5 weeks | No editing in the browser |
| 1B. All phases: viewing, editing, output | The browser does what the desktop does | 5.5 to 8.5 weeks |
| 2A. Prefix `WEBLib.FNCC` | Matches FNC's own WEB units (`WEBLib.TMSFNC*`) | Uses TMS's prefix for our units |
| 2B. Prefix `WEB.FNCC` | Our own name | Out of step with FNC |
| 3A. Pointer-free core data in the shared master, for every framework | One implementation of each class | The desktop's hot path changes; speed risk |
| 3B. A WEB-only implementation of those classes behind `{$IFDEF CADSYS_WEB}`, same public API | The desktop code does not change at all | About 1,500 to 2,500 lines exist twice; fixes in those classes are made in both |
| 3C. A separate WEB copy of `FNCCADSys4` | None worth having | 26,000 lines kept in step by hand; not workable |
| 4A. Default vector fonts compiled into a unit | There before the first paint; no fetch | A generated unit to keep current |
| 4B. Fonts fetched as `.json` at start-up | No generated unit | Asynchronous; text cannot be measured until they arrive |
| 5A. CADSysFNC demo first | In this repository; no outside dependency | - |
| 5B. A Masterplanner viewer, or a Miletus build first | Closer to a real use | Depends on another repository's plan |

## Recommendation
1B or 1A as Jacco prefers; 2A; 3A for one implementation, with 3B as the safe alternative; 4A; 5A.

## Decision
Jacco Uijlenhoet, 2026-11-05:

1. **1B**, all phases.
2. **2A**, `WEBLib.FNCC`.
3. **3B**, a WEB-only implementation behind `{$IFDEF CADSYS_WEB}`: the desktop core is not touched, because of the
   speed risk. 3C was ruled out as not workable.
4. **4A**, fonts compiled into a unit.
5. **5A**, the CADSysFNC demo.

## Consequences
- `Tools\gen-units.ps1` gets a fourth tree, `Generated\WEB`, and `WEBLib.FNCCADSys.inc` defines `CADSYS_WEB`.
- The point sets, the object list, the model transforms and the `Draw2DSubSet` buffers get WEB-only versions; the
  shared tests for them must run in the desktop suites and in the browser suite.
- Once the WEB versions are proven, they can be benchmarked on the desktop; if as fast, a later decision can fold the
  desktop onto them and remove the duplicates.
- The work starts with phase 0, the probe, and follows the phases and gates in the plan.
