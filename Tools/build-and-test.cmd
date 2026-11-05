@echo off
rem ---------------------------------------------------------------------
rem Builds and runs the DUnitX suites. Logs land in Tools\logs so the
rem session working on the port can read them.
rem
rem   build-and-test.cmd [BDSVER]      BDSVER defaults to 23.0 (Delphi 12)
rem
rem Why dcc32 and not msbuild: msbuild hands the compiler the IDE's whole
rem Win32 library search path on the command line. With this many TMS
rem products installed that is well past the 32000 character limit
rem Windows allows, and the build dies with MSB6003 "the specified task
rem executable dcc could not be run". A generated dcc32.cfg carries the
rem paths in a file instead, and the command line stays short.
rem
rem The package is not built here - it has nothing these projects need
rem (the tests compile the library from source, through Generated\VCL
rem on the unit path) and building it is what tripped the limit. Build and
rem install FNCCadSysVCL.dproj in the IDE as usual.
rem ---------------------------------------------------------------------
setlocal
set BDSVER=%1
if "%BDSVER%"=="" set BDSVER=23.0
set ROOT=%~dp0..
set LOGS=%~dp0logs
set OUT=%~dp0build
if not exist "%LOGS%" mkdir "%LOGS%"
if not exist "%OUT%" mkdir "%OUT%"
if not exist "%OUT%\dcu" mkdir "%OUT%\dcu"
if not exist "%OUT%\bin" mkdir "%OUT%\bin"

rem --- where is Delphi -------------------------------------------------
set BDSROOT=
for /f "tokens=2,*" %%a in ('reg query "HKCU\Software\Embarcadero\BDS\%BDSVER%" /v RootDir 2^>nul ^| find "RootDir"') do set BDSROOT=%%b
if "%BDSROOT%"=="" for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Embarcadero\BDS\%BDSVER%" /v RootDir 2^>nul ^| find "RootDir"') do set BDSROOT=%%b
if "%BDSROOT%"=="" (
  echo Delphi BDS %BDSVER% not found in the registry. > "%LOGS%\build.log"
  type "%LOGS%\build.log"
  exit /b 2
)
set DCC="%BDSROOT%bin\dcc32.exe"
if not exist %DCC% (
  echo dcc32 not found at %DCC% > "%LOGS%\build.log"
  type "%LOGS%\build.log"
  exit /b 2
)

rem --- where is TMS FNC Core (only the FNC suite needs it) -------------
set FNCCORE=
for %%d in (Release Debug) do (
  for %%r in ("%CADSYS_TMS%" "%ROOT%\..\TMS\Products" "%ROOT%\..\..\Products" "%ROOT%\..\Products") do (
    if not defined FNCCORE if exist "%%~r\tms.fnc.core\packages\d12\Win32\%%d\VCL.TMSFNCGraphics.dcu" set FNCCORE=%%~r\tms.fnc.core\packages\d12\Win32\%%d
  )
)

rem --- the generated unit copies --------------------------------------
rem Sources is the master; the compiler reads Generated\VCL. Run from
rem here rather than by hand, because a tree generated from memory is a
rem tree that can be stale, and a stale one fails as a compiler error in
rem a file nobody edited.
call "%~dp0gen-units.cmd" -Quiet
if errorlevel 1 (
  echo gen-units.cmd failed - see the output above. > "%LOGS%\build.log"
  type "%LOGS%\build.log"
  exit /b 2
)
set LIB=%ROOT%\Generated\VCL

rem --- the config the compiler reads instead of a huge command line ----
set CFG=%OUT%\dcc32.cfg
> "%CFG%" echo -U"%BDSROOT%lib\Win32\release;%LIB%;%ROOT%\Test;%FNCCORE%"
>>"%CFG%" echo -I"%BDSROOT%lib\Win32\release;%LIB%;%ROOT%\Test"
>>"%CFG%" echo -R"%BDSROOT%lib\Win32\release;%LIB%;%ROOT%\Test"
>>"%CFG%" echo -O"%BDSROOT%lib\Win32\release"
>>"%CFG%" echo -NSVcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;System;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win
>>"%CFG%" echo -N0"%OUT%\dcu"
>>"%CFG%" echo -E"%OUT%\bin"
>>"%CFG%" echo -$D+
>>"%CFG%" echo -$L+
>>"%CFG%" echo -$Y+
>>"%CFG%" echo -DDEBUG

rem --- data files the CAD2D demos need beside their exe ---------------
rem Both demos build into %OUT%\bin and both load the vector font from
rem the folder they run in, so whichever script you ran last, the font
rem is there. Copied rather than duplicated in the repository.
if not exist "%OUT%\bin" mkdir "%OUT%\bin"
copy /Y "%ROOT%\Demos\CAD2D\data\*.*" "%OUT%\bin\" >nul 2>&1

pushd "%OUT%"

rem --- main suite ------------------------------------------------------
echo === build %DATE% %TIME% (BDS %BDSVER%) > "%LOGS%\build.log"
echo --- dcc32 config: >> "%LOGS%\build.log"
type "%CFG%" >> "%LOGS%\build.log"
echo --- main suite >> "%LOGS%\build.log"
%DCC% -B "%ROOT%\Test\CADSys4Tests.dpr" >> "%LOGS%\build.log" 2>&1
set BUILDERR=%ERRORLEVEL%
echo === dcc32 exit %BUILDERR% >> "%LOGS%\build.log"
if not "%BUILDERR%"=="0" (
  echo BUILD FAILED - see Tools\logs\build.log
  del "%LOGS%\test.log" 2>nul
  popd
  exit /b %BUILDERR%
)

echo === tests %DATE% %TIME% > "%LOGS%\test.log"
"%OUT%\bin\CADSys4Tests.exe" --exitbehavior:Continue --xmlfile:"%LOGS%\results.xml" >> "%LOGS%\test.log" 2>&1
set TESTERR=%ERRORLEVEL%
echo === test exit %TESTERR% >> "%LOGS%\test.log"
if "%TESTERR%"=="0" (echo MAIN SUITE PASSED) else (echo MAIN SUITE FAILED - see Tools\logs\test.log)

rem --- FNC backend suite ----------------------------------------------
echo === fnc build %DATE% %TIME% > "%LOGS%\build-fnc.log"
del "%LOGS%\test-fnc.log" 2>nul
if "%FNCCORE%"=="" (
  echo TMS FNC Core dcu folder not found - skipping the FNC suite. >> "%LOGS%\build-fnc.log"
  echo FNC SUITE SKIPPED - see Tools\logs\build-fnc.log
  popd
  exit /b %TESTERR%
)
%DCC% -B "%ROOT%\Test\CADSysFNCTests.dpr" >> "%LOGS%\build-fnc.log" 2>&1
set FNCBUILDERR=%ERRORLEVEL%
echo === dcc32 exit %FNCBUILDERR% >> "%LOGS%\build-fnc.log"
if not "%FNCBUILDERR%"=="0" (
  echo FNC BUILD FAILED - see Tools\logs\build-fnc.log
  popd
  exit /b %FNCBUILDERR%
)
echo === fnc tests %DATE% %TIME% > "%LOGS%\test-fnc.log"
"%OUT%\bin\CADSysFNCTests.exe" --exitbehavior:Continue --xmlfile:"%LOGS%\results-fnc.xml" >> "%LOGS%\test-fnc.log" 2>&1
set FNCERR=%ERRORLEVEL%
echo === test exit %FNCERR% >> "%LOGS%\test-fnc.log"
if "%FNCERR%"=="0" (echo FNC SUITE PASSED) else (echo FNC SUITE FAILED - see Tools\logs\test-fnc.log)

popd
if not "%TESTERR%"=="0" exit /b %TESTERR%
exit /b %FNCERR%
