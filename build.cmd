@echo off
rem ---------------------------------------------------------------------
rem The gate of docs\claude-workflow.md, section 5: a change is done when
rem the last line is BUILD OK, TESTS PASSED.
rem
rem   build.cmd [BDSVER]      BDSVER defaults to 23.0 (Delphi 12)
rem
rem Runs the scripts in Tools\ in turn, which regenerate Generated\ first:
rem the two test suites, the VCL demo, the FMX check and demo, and the
rem four packages (built, not installed). Logs: Tools\logs\
rem
rem TMS FNC is looked for beside this folder. A checkout elsewhere, such
rem as a worktree, sets CADSYS_TMS to the Products folder.
rem
rem Exit: 0 ok, 1 tests failed, 2 tools or TMS FNC missing,
rem       3 a directive inside a brace comment, 6 compiler error
rem ---------------------------------------------------------------------
setlocal EnableExtensions
set ROOT=%~dp0
set TOOLS=%ROOT%Tools
set LOGS=%TOOLS%\logs
set BDSVER=%1
if "%BDSVER%"=="" set BDSVER=23.0
if not exist "%LOGS%" mkdir "%LOGS%"

rem --- directives inside brace comments --------------------------------
rem Python is not required: without it the check is reported as skipped.
python --version >nul 2>&1
if errorlevel 1 goto nopython
pushd "%ROOT%"
python Tools\check-comments.py
set ERR=%ERRORLEVEL%
popd
if not "%ERR%"=="0" goto badcomment
goto suites
:nopython
echo COMMENT CHECK SKIPPED - Python not found

rem --- the suites ------------------------------------------------------
rem build-and-test.cmd's exit code cannot say what went wrong: it hands on
rem dcc32's code or the number of failed tests. Its logs can, so the ones
rem from an earlier run go first.
:suites
del "%LOGS%\build.log" "%LOGS%\test.log" "%LOGS%\build-fnc.log" "%LOGS%\test-fnc.log" 2>nul
call "%TOOLS%\build-and-test.cmd" %BDSVER%
findstr /B /C:"=== build " "%LOGS%\build.log" >nul 2>&1 || goto notools
if not exist "%LOGS%\test.log" goto compilefail
findstr /B /C:"=== test exit 0" "%LOGS%\test.log" >nul 2>&1 || goto testfail
findstr /C:"skipping the FNC suite" "%LOGS%\build-fnc.log" >nul 2>&1 && goto notools
if not exist "%LOGS%\test-fnc.log" goto compilefail
findstr /B /C:"=== test exit 0" "%LOGS%\test-fnc.log" >nul 2>&1 || goto testfail

rem --- the demos and the packages --------------------------------------
call "%TOOLS%\build-vcl.cmd" %BDSVER%
call :checkbuild || goto end
call "%TOOLS%\build-fmx.cmd" %BDSVER%
call :checkbuild || goto end
call "%TOOLS%\build-packages.cmd" %BDSVER% > "%LOGS%\build-packages-output.log"
call :checkbuild || goto packagesfail

echo.
echo Test totals:
findstr /C:"Tests Found" /C:"Tests Passed" /C:"Tests Failed" /C:"Tests Errored" /C:"Tests Ignored" "%LOGS%\test.log" "%LOGS%\test-fnc.log"
echo BUILD OK, TESTS PASSED
exit /b 0

rem Exit 2 from these scripts means a tool is missing; dcc32 itself gives 1.
:checkbuild
set ERR=%ERRORLEVEL%
if "%ERR%"=="0" exit /b 0
set RESULT=6
if "%ERR%"=="2" set RESULT=2
exit /b 1

:packagesfail
type "%LOGS%\build-packages-output.log"
:end
echo BUILD FAILED - see Tools\logs
exit /b %RESULT%

:badcomment
echo BUILD FAILED - a directive inside a brace comment, see above
exit /b 3

:notools
echo BUILD FAILED - Delphi or TMS FNC not found, see Tools\logs
exit /b 2

:compilefail
echo BUILD FAILED - compiler error, see Tools\logs
exit /b 6

:testfail
echo BUILD OK, TESTS FAILED - see Tools\logs\test.log and test-fnc.log
exit /b 1
