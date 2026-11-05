# Notes for Claude (and anyone new to the code)

The way of working is `docs\claude-workflow.md` (decision 0001). The short version:

- Delphi 12 (BDS 23.0), Win32 builds with `dcc32`, never `msbuild`. TMS FNC Core from `..\TMS\Products`, or `CADSYS_TMS`
  in a checkout elsewhere. One set of sources for VCL and FMX; FMX is what Masterplanner and VisualPlannerFNC use. LCL
  is carried along but has never been built.
- **Edit `Sources\VCL.*`, never `Generated\`.** `Tools\gen-units.cmd` writes the per-framework copies, and every build
  script runs it first. An error in `FMX.FNCCADSys4.pas(n)` is line n of the master.
- The plan is `docs\masterplanner-changes.md`: change IDs CS-xx (the MP-xxx and WP-x.y in it are Masterplanner's). Its
  master copy is `masterplanner\docs\library-changes\CADSysFNC_changes.md`; new items are copied in from there. Mention
  the IDs in commits and pull requests (`CS-21: ...`). "Continue with CS-xx" is a complete instruction. When an item is
  done, say so in that document, with the commit.
- New library units: add them to the table in `Tools\gen-units.ps1`, to the runtime packages in `Packages\delphi` and to
  `Test\CADSysFMXCheck.dpr`. Tests: `Test\CADSys4.Tests.<area>.pas`, in the `.dpr` and `.dproj`. What draws through the
  FNC backend goes in `CADSysFNCTests`.
- Existing drawings, JSON files and the applications keep working. Format changes go in `docs\json-format.md`.
- Text files use CRLF in the working tree. Files keep their encoding (the masters are UTF-8 with a BOM); new text files
  stay ASCII unless they need otherwise.
- Work in this folder on `master`: no worktrees, no `claude/<topic>` branches unless Jacco asks (decision 0003). A
  session started in a worktree anyway edits and commits there, then moves `master` to the result and runs `build.cmd`
  in the main folder: the applications compile against `Generated\FMX` here.
- After a change run `build.cmd`; it must end with `BUILD OK, TESTS PASSED`. Logs are in `Tools\logs\`. Then check
  `git status` and commit to `master`.
- **Push only when Jacco asks**: the repository is public. There is no CI (decision 0004, Proposed); report "no CI"
  rather than a CI result. No self-hosted runner on this repository unless that decision says so.
- Choices the developer should make: write a decision record in `docs\decisions` (status *Proposed*), give a
  recommendation, and ask. Do not build on a proposal before it is accepted.
- Other repositories are not changed from here. What an application has to do after a library change goes on the list
  for Jacco.
- Never a bare `git stash`. Paths with backslashes and Delphi braces: Edit tool, not `sed`.
- End each piece of work with: what changed, the commit and build result, and what is left for Jacco.
