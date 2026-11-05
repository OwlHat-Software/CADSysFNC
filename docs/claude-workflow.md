# Working with Claude Code - the workflow

This is how CADSysFNC is maintained with Claude Code. It is Masterplanner's workflow
(`masterplanner\docs\claude-workflow.md`), adapted: CADSysFNC is a public library with no program of its own, its
plan comes from the applications that use it, and its default branch is `master`. Decision numbers below are this
repository's. Section 9 explains how this file relates to `CLAUDE.md`.

## 1. Roles

- **The developer decides.** Scope, choices between options, priorities and pushes are theirs.
- **Claude implements.** It writes the code, tests and docs, builds and commits.
- When a choice comes up that the developer should make, Claude stops, writes it down with a recommendation, and
  asks (section 4). It does not build on a choice that has not been made.
- Anything Claude cannot do itself (checks by hand, a paste into PowerPoint, a real printer, work in other
  repositories) goes on a clear list for the developer at the end of each piece of work.

## 2. The documents in `docs\` lead

| Document | What it holds | IDs |
|---|---|---|
| `docs\masterplanner-changes.md` | The plan: what the applications need from the library, with priority, status and a test per item | CS-xx |
| `docs\decisions\` | One decision record per choice (section 4) | 0001, 0002, ... |
| `README.md`, `docs\migrating.md`, `docs\output.md`, `docs\paper-space.md`, `docs\json-format.md`, `docs\drawing-speed.md` | The library's user documentation, kept up to date with the work | - |
| `docs\port\` | The port history. A record, not a plan; read it before changing the drawing path | - |

- CS items are written by the applications. The master copy of the spec is
  `masterplanner\docs\library-changes\CADSysFNC_changes.md`; Masterplanner adds items there, and they are copied
  into `docs\masterplanner-changes.md` here, where the status is kept. The MP-xxx and WP-x.y numbers in it are
  Masterplanner's.
- Work goes one CS item at a time: Must before Should before Could. "Continue with CS-21" is a complete instruction.
- Every commit message names the IDs it serves (`CS-21: PDF keeps the alpha of a fill or pen`). Work that no CS
  item asks for has no ID, and says what it does.
- When a CS item is done, its test passes and the spec says so: `Done (<commit>)` in the table and a "Done as"
  line in its section.

## 3. Where Claude works

- In the project folder itself, on `master` (decision 0003). No worktrees and no `claude/<topic>` branches unless
  the developer asks for them. The point: Masterplanner and VisualPlannerFNC compile against `Generated\FMX` in this
  folder, and CI in those repositories reads it as it is on disk, so this folder is what the applications get.
- Larger or risky work can still go on a branch with a pull request when the developer asks.
- If a session is started in a worktree anyway, edit and commit there, then move `master` to the result and run
  `build.cmd` in the main folder, so `Generated\` is current.

## 4. Decision records

- Template: `docs\decisions\0000-template.md`, with the sections Question / Options (a table with For and
  Against) / Recommendation / Decision / Consequences.
- Claude writes a new record with status **Proposed**, gives its recommendation, and asks the developer, offering
  the options with the recommended one first.
- After the answer it sets **Accepted**, writes who chose what and when, and only then builds on it.
- A later change to a decision is a new record (or a dated note in the old one) that says what it amends.
- `docs\decisions\README.md` keeps an index.

## 5. One build script as the gate

`build.cmd` in the root is the gate. It calls the scripts in `Tools\`, which remain usable on their own. In one run
it:

1. Checks that no compiler directive hides inside a brace comment (`Tools\check-comments.py`). This needs Python;
   without it the build says the check was skipped and goes on.
2. Regenerates `Generated\` from `Sources\` (each script in `Tools\` does this first).
3. Builds and runs both DUnitX suites (`Tools\build-and-test.cmd`). Both must have run: that script can skip the FNC
   suite, and the gate treats a skip as a failure.
4. Builds the VCL demo (`Tools\build-vcl.cmd`).
5. Builds the FMX link-everything project and the FMX demo (`Tools\build-fmx.cmd`).
6. Builds all four packages without installing them (`Tools\build-packages.cmd`).

It ends with one fixed line - `BUILD OK, TESTS PASSED` - and distinct exit codes (1 tests failed, 2 tools or TMS FNC
missing, 3 a directive inside a comment, 6 compiler error). Claude runs it after every change; a change is not done
until that line appears. Logs go to `Tools\logs\`.

TMS FNC is looked for beside this folder (`..\TMS\Products`). A checkout elsewhere, such as a worktree, sets
`CADSYS_TMS` to the `Products` folder.

## 6. Tests and code rules

- **`Sources\VCL.*` is the master.** `Generated\` is a build artifact: never edited, never committed. A compiler
  error in `FMX.FNCCADSys4.pas(16817)` is line 16817 of the master.
- New library units go in the table in `Tools\gen-units.ps1` with the frameworks they belong to, in the runtime
  packages in `Packages\delphi` and in `Test\CADSysFMXCheck.dpr`; tests go in the suite's `.dpr` and `.dproj`.
- The library's behaviour gets DUnitX tests in `Test\CADSys4.Tests.<area>.pas`. What draws through the FNC backend into
  a `TTMSFNCGraphics` bitmap goes in `CADSysFNCTests`. A CS item's test comes from its section in the spec.
- Existing drawings, JSON files and the applications keep working: a change does not break the format or the API
  without a decision record. Format changes also go in `docs\json-format.md`.
- Output that cannot be unit tested (a real printer, a paste into Office, how a demo looks) goes on the list for the
  developer. Passing a compiler is not the same as working: the README's status table claims only what has been run.
- There are no UI text translations: this is a library, with English messages.
- Text files use CRLF in the working tree; `.gitattributes` stores them as LF. Files keep their encoding (the masters
  are UTF-8 with a BOM); new text files stay ASCII unless they need otherwise.

## 7. Commit, push, CI

- After a green build: commit (one coherent change per commit, IDs in the message).
- Push only when the developer asks. This repository is public: a push is a publication. The applications do not
  need one, as they read this folder.
- **There is no CI yet.** The other repositories run CI on a self-hosted runner, which is not safe to copy to a
  public repository as it stands, and GitHub's hosted runners have neither Delphi nor TMS FNC. The choice is in
  decision 0004. Until it is made, `build.cmd` is the only check: report "no CI" rather than a CI result, and check
  `git status` before a commit, because nothing else notices a file that was not added.

## 8. Rules that saved time

- Other repositories are never changed from this one. What an application has to do after a library change goes on
  the list for the developer; what the library needs from an application arrives as a CS item.
- The library has to keep compiling for the applications: an API change that breaks one is named in the commit and on
  that list.
- Never a bare `git stash` (the stash is shared between sessions); use a temporary commit.
- Paths with backslashes and Delphi braces: edit with the Edit tool or a literal string replace, not `sed`/`perl`.
- `msbuild` is not used: with this many TMS products it dies on the command-line limit (`Test\README.md`). The scripts
  call `dcc32` with a generated config.
- Report faithfully: if a test fails or a step was skipped, say so with the output.
- End each piece of work with: what changed, the commit and build result, and what is left for the developer.

## 9. CLAUDE.md

`CLAUDE.md` in the root is the short version of this file, loaded into every session. Change the two together.

## 10. What is set up here, and what is not

Set up: `CLAUDE.md`, `build.cmd`, `docs\decisions\` with the template, the index and 0001-0004, and the plan brought up
to CS-21.

Not used from Masterplanner's workflow: requirements and an implementation plan of its own (the spec plays that part),
`docs\library-changes\` (nothing goes out to other libraries), translations, the architecture rule on UI units
(the library exists to draw through them; the FMX build, which leaves out the Vcl namespaces, does that job), scripted
UI checks and screenshots, and an installer.

Open: CI (decision 0004).
