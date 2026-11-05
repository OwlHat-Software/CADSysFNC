@echo off
rem ---------------------------------------------------------------------
rem Compiles the library with CADSYS_FMX defined. Nothing is run; the
rem point is the compiler's opinion.
rem
rem   build-fmx.cmd [BDSVER]           BDSVER defaults to 23.0 (Delphi 12)
rem
rem Two things get built:
rem
rem   Test\CADSysFMXCheck.dpr   - links every unit, runs nothing. The
rem                               compile-only error loop.
rem   Demos\CAD2D\FMX          - the FMX port of the CAD2D demo, the
rem                               same project the IDE opens. Compiling
rem                               is not the same as working.
rem
rem Log: Tools\logs\build-fmx.log
rem
rem Two deliberate differences from build-and-test.cmd:
rem
rem   -NS has the FMX namespaces and NOT the Vcl ones. A bare 'Graphics'
rem   or 'Controls' left in a shared uses clause would otherwise resolve
rem   to the VCL unit and compile happily here while failing in a real
rem   FMX project.
rem
rem   The dcus go to their own folder. Same unit names, different
rem   defines - mixing them with the VCL build's dcus gives stale or
rem   wrong-framework symbols and errors that make no sense.
rem ---------------------------------------------------------------------
setlocal
set BDSVER=%1
if "%BDSVER%"=="" set BDSVER=23.0
set ROOT=%~dp0..
set LOGS=%~dp0logs
set OUT=%~dp0build
if not exist "%LOGS%" mkdir "%LOGS%"
if not exist "%OUT%" mkdir "%OUT%"
if not exist "%OUT%\fmx" mkdir "%OUT%\fmx"
if not exist "%OUT%\dcu-fmx" mkdir "%OUT%\dcu-fmx"
if not exist "%OUT%\bin" mkdir "%OUT%\bin"

rem --- where is Delphi -------------------------------------------------
set BDSROOT=
for /f "tokens=2,*" %%a in ('reg query "HKCU\Software\Embarcadero\BDS\%BDSVER%" /v RootDir 2^>nul ^| find "RootDir"') do set BDSROOT=%%b
if "%BDSROOT%"=="" for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Embarcadero\BDS\%BDSVER%" /v RootDir 2^>nul ^| find "RootDir"') do set BDSROOT=%%b
if "%BDSROOT%"=="" (
  echo Delphi BDS %BDSVER% not found in the registry. > "%LOGS%\build-fmx.log"
  type "%LOGS%\build-fmx.log"
  exit /b 2
)
set DCC="%BDSROOT%bin\dcc32.exe"
if not exist %DCC% (
  echo dcc32 not found at %DCC% > "%LOGS%\build-fmx.log"
  type "%LOGS%\build-fmx.log"
  exit /b 2
)

rem --- TMS FNC Core: the FMX dcus live beside the VCL ones -------------
set FNCCORE=
for %%d in (Release Debug) do (
  for %%r in ("%CADSYS_TMS%" "%ROOT%\..\TMS\Products" "%ROOT%\..\..\Products" "%ROOT%\..\Products") do (
    if not defined FNCCORE if exist "%%~r\tms.fnc.core\packages\d12\Win32\%%d\FMX.TMSFNCGraphics.dcu" set FNCCORE=%%~r\tms.fnc.core\packages\d12\Win32\%%d
  )
)
if "%FNCCORE%"=="" (
  echo FMX build of TMS FNC Core not found. > "%LOGS%\build-fmx.log"
  echo Looked for FMX.TMSFNCGraphics.dcu under tms.fnc.core\packages\d12\Win32. >> "%LOGS%\build-fmx.log"
  echo Build the FMXTMSFNCCorePkg package in the IDE first. >> "%LOGS%\build-fmx.log"
  type "%LOGS%\build-fmx.log"
  exit /b 2
)

rem --- the generated unit copies --------------------------------------
rem Sources is the master; the compiler reads Generated\FMX. Run from
rem here rather than by hand, because a tree generated from memory is a
rem tree that can be stale, and a stale one fails as a compiler error in
rem a file nobody edited.
call "%~dp0gen-units.cmd" -Quiet
if errorlevel 1 (
  echo gen-units.cmd failed - see the output above. > "%LOGS%\build-fmx.log"
  type "%LOGS%\build-fmx.log"
  exit /b 2
)
set LIB=%ROOT%\Generated\FMX

rem dcc32 reads dcc32.cfg from the current directory, which is how
rem build-and-test.cmd already does it; a separate directory keeps the
rem two configurations from seeing each other.
set CFG=%OUT%\fmx\dcc32.cfg
rem Demos\common is on the unit path because dcc32 resolves a dpr's
rem "unit in 'path'" clause against the CURRENT directory, not against
rem the dpr's own folder, and only then falls back to -U. This script
rem compiles from Tools\build\fmx, so every such path in a demo dpr
rem misses and has to be found here instead.
> "%CFG%" echo -U"%BDSROOT%lib\Win32\release;%LIB%;%ROOT%\Test;%ROOT%\Demos\CAD2D\FMX;%ROOT%\Demos\common;%FNCCORE%"
>>"%CFG%" echo -I"%BDSROOT%lib\Win32\release;%LIB%;%ROOT%\Test;%ROOT%\Demos\CAD2D\FMX;%ROOT%\Demos\common"
>>"%CFG%" echo -R"%BDSROOT%lib\Win32\release;%LIB%;%ROOT%\Test;%ROOT%\Demos\CAD2D\FMX;%ROOT%\Demos\common"
>>"%CFG%" echo -O"%BDSROOT%lib\Win32\release"
>>"%CFG%" echo -NSSystem;Xml;Data;Datasnap;Web;Soap;FMX;Winapi;System.Win
>>"%CFG%" echo -N0"%OUT%\dcu-fmx"
>>"%CFG%" echo -E"%OUT%\bin"
>>"%CFG%" echo -$D+
>>"%CFG%" echo -$L+
>>"%CFG%" echo -$Y+
>>"%CFG%" echo -DDEBUG;CADSYS_FMX

rem --- a stray project .cfg would win ----------------------------------
rem dcc32 reads a config named after the project it is compiling, from
rem that project's own folder, as well as the dcc32.cfg in the current
rem directory - and the project one wins. Four of these were inherited
rem from the original author's Delphi 5 install, carrying
rem -LE"c:\programmi\borland\delphi5\Projects\Bpl", a -U pointing at a
rem source folder on his machine and -$D- against our -$D+. They are
rem deleted; this refuses to compile if one ever comes back, because
rem the alternative is a build configured by a file nobody read.
set STRAYCFG=
if exist "%ROOT%\Demos\CAD2D\FMX\CadSysFMX.cfg" set STRAYCFG=%ROOT%\Demos\CAD2D\FMX\CadSysFMX.cfg
if exist "%ROOT%\Test\CADSysFMXCheck.cfg" set STRAYCFG=%ROOT%\Test\CADSysFMXCheck.cfg
if defined STRAYCFG (
  echo A stale project config is present: %STRAYCFG% > "%LOGS%\build-fmx.log"
  echo dcc32 would read it instead of this script's. Delete it. >> "%LOGS%\build-fmx.log"
  type "%LOGS%\build-fmx.log"
  exit /b 2
)

pushd "%OUT%\fmx"
echo === fmx build %DATE% %TIME% (BDS %BDSVER%) > "%LOGS%\build-fmx.log"
echo --- dcc32 config: >> "%LOGS%\build-fmx.log"
type "%CFG%" >> "%LOGS%\build-fmx.log"
echo --- compiling with CADSYS_FMX >> "%LOGS%\build-fmx.log"
%DCC% -B "%ROOT%\Test\CADSysFMXCheck.dpr" >> "%LOGS%\build-fmx.log" 2>&1
set ERR=%ERRORLEVEL%
echo === dcc32 exit %ERR% >> "%LOGS%\build-fmx.log"
if not "%ERR%"=="0" (
  popd
  echo FMX BUILD FAILED - see Tools\logs\build-fmx.log
  exit /b %ERR%
)

rem The same project the IDE opens - Demos\CAD2D\FMX\CadSysFMX.dproj -
rem so the two ways of building it cannot drift apart. CADSYS_FMX is
rem still set in both, and is now a belt to the tree's braces: every unit
rem in Generated\FMX includes FMX.FNCCADSys.inc, which defines it. If the
rem two ever disagree - an FMX project pointed at the VCL tree - the
rem include says so at the first unit instead of at the first
rem incompatible type.
echo --- demo: Demos\CAD2D\FMX >> "%LOGS%\build-fmx.log"
%DCC% -B "%ROOT%\Demos\CAD2D\FMX\CadSysFMX.dpr" >> "%LOGS%\build-fmx.log" 2>&1
set DEMOERR=%ERRORLEVEL%
echo === dcc32 exit %DEMOERR% >> "%LOGS%\build-fmx.log"
popd
if not "%DEMOERR%"=="0" (
  echo FMX LIBRARY OK, DEMO FAILED - see Tools\logs\build-fmx.log
  exit /b %DEMOERR%
)
rem --- data files the demo needs beside the exe ----------------------
rem The vector font is what the text tool and the DXF reader use, the
rem sample DXF is there to import, and the test patterns are there for
rem the image tool. Copied rather than duplicated in the repository, so
rem there is one copy to keep correct.
copy /Y "%ROOT%\Demos\CAD2D\data\*.*" "%OUT%\bin\" >nul 2>&1

echo FMX BUILD OK - run Tools\build\bin\CadSysFMX.exe
exit /b 0
