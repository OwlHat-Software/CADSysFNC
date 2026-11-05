@echo off
rem ---------------------------------------------------------------------
rem Builds the VCL demo. Nothing is run; the point is the compiler's
rem opinion and an exe to click.
rem
rem   build-vcl.cmd [BDSVER]           BDSVER defaults to 23.0 (Delphi 12)
rem
rem This is the counterpart of build-fmx.cmd. Read the two side by side:
rem the differences between them are the differences between the
rem frameworks, and nothing else.
rem
rem   Demos\CAD2D\VCL          - the same project the IDE opens.
rem                              Compiling is not the same as working.
rem
rem Log: Tools\logs\build-vcl.log
rem
rem There is no VCL equivalent of Test\CADSysFMXCheck.dpr here, and
rem there does not need to be: build-and-test.cmd compiles the whole
rem library with CADSYS_VCL on its way to running the suites. The FMX
rem side needs a link-everything project precisely because it has no
rem suite to run.
rem
rem The dcus go to the same folder build-and-test.cmd uses, which is
rem safe here and would not be on the FMX side: same defines, same
rem namespaces, same library. The FMX build keeps its own folder
rem because mixing dcus built with different defines gives stale or
rem wrong-framework symbols and errors that make no sense.
rem ---------------------------------------------------------------------
setlocal
set BDSVER=%1
if "%BDSVER%"=="" set BDSVER=23.0
set ROOT=%~dp0..
set LOGS=%~dp0logs
set OUT=%~dp0build
if not exist "%LOGS%" mkdir "%LOGS%"
if not exist "%OUT%" mkdir "%OUT%"
if not exist "%OUT%\vcl" mkdir "%OUT%\vcl"
if not exist "%OUT%\dcu" mkdir "%OUT%\dcu"
if not exist "%OUT%\bin" mkdir "%OUT%\bin"

rem --- where is Delphi -------------------------------------------------
set BDSROOT=
for /f "tokens=2,*" %%a in ('reg query "HKCU\Software\Embarcadero\BDS\%BDSVER%" /v RootDir 2^>nul ^| find "RootDir"') do set BDSROOT=%%b
if "%BDSROOT%"=="" for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Embarcadero\BDS\%BDSVER%" /v RootDir 2^>nul ^| find "RootDir"') do set BDSROOT=%%b
if "%BDSROOT%"=="" (
  echo Delphi BDS %BDSVER% not found in the registry. > "%LOGS%\build-vcl.log"
  type "%LOGS%\build-vcl.log"
  exit /b 2
)
set DCC="%BDSROOT%bin\dcc32.exe"
if not exist %DCC% (
  echo dcc32 not found at %DCC% > "%LOGS%\build-vcl.log"
  type "%LOGS%\build-vcl.log"
  exit /b 2
)

rem --- TMS FNC Core: the VCL dcus live beside the FMX ones -------------
set FNCCORE=
for %%d in (Release Debug) do (
  for %%r in ("%CADSYS_TMS%" "%ROOT%\..\TMS\Products" "%ROOT%\..\..\Products" "%ROOT%\..\Products") do (
    if not defined FNCCORE if exist "%%~r\tms.fnc.core\packages\d12\Win32\%%d\VCL.TMSFNCGraphics.dcu" set FNCCORE=%%~r\tms.fnc.core\packages\d12\Win32\%%d
  )
)
if "%FNCCORE%"=="" (
  echo VCL build of TMS FNC Core not found. > "%LOGS%\build-vcl.log"
  echo Looked for VCL.TMSFNCGraphics.dcu under tms.fnc.core\packages\d12\Win32. >> "%LOGS%\build-vcl.log"
  echo Build the VCLTMSFNCCorePkg package in the IDE first. >> "%LOGS%\build-vcl.log"
  type "%LOGS%\build-vcl.log"
  exit /b 2
)

rem --- the generated unit copies --------------------------------------
rem Sources is the master; the compiler reads Generated\VCL. Run from
rem here rather than by hand, because a tree generated from memory is a
rem tree that can be stale, and a stale one fails as a compiler error in
rem a file nobody edited.
call "%~dp0gen-units.cmd" -Quiet
if errorlevel 1 (
  echo gen-units.cmd failed - see the output above. > "%LOGS%\build-vcl.log"
  type "%LOGS%\build-vcl.log"
  exit /b 2
)
set LIB=%ROOT%\Generated\VCL

rem dcc32 reads dcc32.cfg from the current directory. A separate
rem directory per script keeps the three configurations from seeing
rem each other.
set CFG=%OUT%\vcl\dcc32.cfg
rem Demos\common is on the unit path because dcc32 resolves a dpr's
rem "unit in 'path'" clause against the CURRENT directory, not against
rem the dpr's own folder, and only then falls back to -U. This script
rem compiles from Tools\build\vcl, so DemoLog's '..\..\common' misses
rem and has to be found here instead.
> "%CFG%" echo -U"%BDSROOT%lib\Win32\release;%LIB%;%ROOT%\Test;%ROOT%\Demos\CAD2D\VCL;%ROOT%\Demos\common;%FNCCORE%"
>>"%CFG%" echo -I"%BDSROOT%lib\Win32\release;%LIB%;%ROOT%\Test;%ROOT%\Demos\CAD2D\VCL;%ROOT%\Demos\common"
>>"%CFG%" echo -R"%BDSROOT%lib\Win32\release;%LIB%;%ROOT%\Test;%ROOT%\Demos\CAD2D\VCL;%ROOT%\Demos\common"
>>"%CFG%" echo -O"%BDSROOT%lib\Win32\release"
>>"%CFG%" echo -NSVcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;System;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win
>>"%CFG%" echo -N0"%OUT%\dcu"
>>"%CFG%" echo -E"%OUT%\bin"
>>"%CFG%" echo -$D+
>>"%CFG%" echo -$L+
>>"%CFG%" echo -$Y+
>>"%CFG%" echo -DDEBUG

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
if exist "%ROOT%\Demos\CAD2D\VCL\CadSysVCL.cfg" set STRAYCFG=%ROOT%\Demos\CAD2D\VCL\CadSysVCL.cfg
if defined STRAYCFG (
  echo A stale project config is present: %STRAYCFG% > "%LOGS%\build-vcl.log"
  echo dcc32 would read it instead of this script's. Delete it. >> "%LOGS%\build-vcl.log"
  type "%LOGS%\build-vcl.log"
  exit /b 2
)

pushd "%OUT%\vcl"
echo === vcl build %DATE% %TIME% (BDS %BDSVER%) > "%LOGS%\build-vcl.log"
echo --- dcc32 config: >> "%LOGS%\build-vcl.log"
type "%CFG%" >> "%LOGS%\build-vcl.log"
rem The same project the IDE opens - Demos\CAD2D\VCL\CadSysVCL.dproj -
rem so the two ways of building it cannot drift apart. CADSYS_VCL is
rem not defined anywhere and does not need to be: every library unit in
rem Generated\VCL includes VCL.FNCCADSys.inc, which defines it. The tree
rem decides the framework now, not the project.
echo --- demo: Demos\CAD2D\VCL >> "%LOGS%\build-vcl.log"
%DCC% -B "%ROOT%\Demos\CAD2D\VCL\CadSysVCL.dpr" >> "%LOGS%\build-vcl.log" 2>&1
set DEMOERR=%ERRORLEVEL%
echo === dcc32 exit %DEMOERR% >> "%LOGS%\build-vcl.log"
popd
if not "%DEMOERR%"=="0" (
  echo VCL BUILD FAILED - see Tools\logs\build-vcl.log
  exit /b %DEMOERR%
)

rem --- data files the demo needs beside the exe ----------------------
rem The vector font is what the text tool and the DXF reader use, the
rem sample DXF is there to import, and the test patterns are there for
rem the image tool. Copied rather than duplicated in the repository, so
rem there is one copy to keep correct.
copy /Y "%ROOT%\Demos\CAD2D\data\*.*" "%OUT%\bin\" >nul 2>&1

echo VCL BUILD OK - run Tools\build\bin\CadSysVCL.exe
exit /b 0
