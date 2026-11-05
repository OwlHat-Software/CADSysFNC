@echo off
rem ---------------------------------------------------------------------
rem Builds all three library packages with dcc32, outside the IDE.
rem
rem   build-packages.cmd [BDSVER]      BDSVER defaults to 23.0 (Delphi 12)
rem
rem Why this exists: the packages were the one thing only the IDE ever
rem built, so the only way to ask "is the package broken?" was to ask
rem the IDE, which answers with whatever else is wrong with the IDE. An
rem access violation inside coreide while installing says nothing about
rem the package source. This script does.
rem
rem It writes its BPL and DCP to Tools\build\pkg and NEVER to the IDE's
rem own folders, so running it cannot disturb, replace or half-replace
rem an installed package. It does not install anything either - a green
rem run here means the package compiles and links, and installing is
rem still a thing you do in the IDE.
rem
rem It runs gen-units first and builds each package from its own tree:
rem the VCL package from Generated\VCL and the FMX one from
rem Generated\FMX. That is what makes the framework a property of the
rem tree rather than of a define somebody has to remember - the include
rem at the top of each unit names its own framework file.
rem
rem Log: Tools\logs\build-packages.log
rem ---------------------------------------------------------------------
setlocal
set BDSVER=%1
if "%BDSVER%"=="" set BDSVER=23.0
set ROOT=%~dp0..
set LOGS=%~dp0logs
set OUT=%~dp0build
set LOG=%LOGS%\build-packages.log
if not exist "%LOGS%" mkdir "%LOGS%"
if not exist "%OUT%" mkdir "%OUT%"
if not exist "%OUT%\pkg" mkdir "%OUT%\pkg"
if not exist "%OUT%\pkg\dcp" mkdir "%OUT%\pkg\dcp"
if not exist "%OUT%\pkg\dcu-vcl" mkdir "%OUT%\pkg\dcu-vcl"
if not exist "%OUT%\pkg\dcu-fmx" mkdir "%OUT%\pkg\dcu-fmx"
rem Old bpls and dcps from before a rename or a LIBSUFFIX change would sit
rem here looking current. FNCCadSysVCL.bpl and FNCCadSysVCL290.bpl side by
rem side is a question nobody should have to answer.
del /q "%OUT%\pkg\*.bpl" >nul 2>&1
del /q "%OUT%\pkg\dcp\*.dcp" >nul 2>&1

rem --- where is Delphi -------------------------------------------------
set BDSROOT=
for /f "tokens=2,*" %%a in ('reg query "HKCU\Software\Embarcadero\BDS\%BDSVER%" /v RootDir 2^>nul ^| find "RootDir"') do set BDSROOT=%%b
if "%BDSROOT%"=="" for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Embarcadero\BDS\%BDSVER%" /v RootDir 2^>nul ^| find "RootDir"') do set BDSROOT=%%b
if "%BDSROOT%"=="" (
  echo Delphi BDS %BDSVER% not found in the registry. > "%LOG%"
  type "%LOG%"
  exit /b 2
)
set DCC="%BDSROOT%bin\dcc32.exe"
if not exist %DCC% (
  echo dcc32 not found at %DCC% > "%LOG%"
  type "%LOG%"
  exit /b 2
)

rem --- the IDE's DCP folder -------------------------------------------
rem A package's requires clause is resolved from .dcp files, not .dcu,
rem and rtl, vcl, fmx and the rest live in the shared folder the IDE
rem writes to. There is no registry value for it, so the usual places
rem are tried in turn.
set DCPDIR=
for %%c in (
  "%PUBLIC%\Documents\Embarcadero\Studio\%BDSVER%\Dcp"
  "%PUBLIC%\Documents\RAD Studio\%BDSVER%\Dcp"
  "%BDSROOT%lib\Win32\release"
) do (
  if not defined DCPDIR if exist "%%~c\rtl.dcp" set DCPDIR=%%~c
)
if "%DCPDIR%"=="" (
  echo Could not find rtl.dcp - the IDE's shared Dcp folder is not where > "%LOG%"
  echo this script looks. Add the right path to the DCPDIR loop. >> "%LOG%"
  type "%LOG%"
  exit /b 2
)

rem --- TMS FNC Core: both frameworks' dcps are in one folder ----------
set FNCCORE=
for %%d in (Release Debug) do (
  for %%r in ("%CADSYS_TMS%" "%ROOT%\..\TMS\Products" "%ROOT%\..\..\Products" "%ROOT%\..\Products") do (
    if not defined FNCCORE if exist "%%~r\tms.fnc.core\packages\d12\Win32\%%d\VCLTMSFNCCorePkg.dcp" set FNCCORE=%%~r\tms.fnc.core\packages\d12\Win32\%%d
  )
)
if "%FNCCORE%"=="" (
  echo VCLTMSFNCCorePkg.dcp not found under tms.fnc.core\packages\d12\Win32. > "%LOG%"
  echo Build the TMS FNC Core packages in the IDE first. >> "%LOG%"
  type "%LOG%"
  exit /b 2
)

rem --- the generated unit copies --------------------------------------
rem Sources is the master and is still a valid VCL tree; the FMX one
rem only exists once this has run.
call "%~dp0gen-units.cmd" -Quiet
if errorlevel 1 (
  echo gen-units.cmd failed - see the output above. > "%LOG%"
  type "%LOG%"
  exit /b 2
)

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
if exist "%ROOT%\Packages\delphi\FNCCadSysVCL.cfg" set STRAYCFG=%ROOT%\Packages\delphi\FNCCadSysVCL.cfg
if exist "%ROOT%\Packages\delphi\FNCCadSysFMX.cfg" set STRAYCFG=%ROOT%\Packages\delphi\FNCCadSysFMX.cfg
if exist "%ROOT%\Packages\delphi\FNCCadSysDEVCL.cfg" set STRAYCFG=%ROOT%\Packages\delphi\FNCCadSysDEVCL.cfg
if exist "%ROOT%\Packages\delphi\FNCCadSysDEFMX.cfg" set STRAYCFG=%ROOT%\Packages\delphi\FNCCadSysDEFMX.cfg
if defined STRAYCFG (
  echo A stale project config is present: %STRAYCFG% > "%LOG%"
  echo dcc32 would read it instead of this script's. Delete it. >> "%LOG%"
  type "%LOG%"
  exit /b 2
)

set DEERR=0
echo === package build %DATE% %TIME% (BDS %BDSVER%) > "%LOG%"
echo --- dcp folder: %DCPDIR% >> "%LOG%"
echo --- fnc core:   %FNCCORE% >> "%LOG%"

rem --- VCL -------------------------------------------------------------
rem Its own directory, its own dcc32.cfg, its own dcu folder: the two
rem packages are built with different defines and different namespaces,
rem and dcus from one are poison to the other.
set CFG=%OUT%\pkg\dcc32.cfg
> "%CFG%" echo -U"%BDSROOT%lib\Win32\release;%DCPDIR%;%ROOT%\Generated\VCL;%FNCCORE%"
>>"%CFG%" echo -I"%BDSROOT%lib\Win32\release;%ROOT%\Generated\VCL"
>>"%CFG%" echo -R"%BDSROOT%lib\Win32\release;%ROOT%\Generated\VCL;%ROOT%\Packages\delphi"
>>"%CFG%" echo -O"%BDSROOT%lib\Win32\release"
>>"%CFG%" echo -NSVcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;System;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win
>>"%CFG%" echo -N0"%OUT%\pkg\dcu-vcl"
>>"%CFG%" echo -LE"%OUT%\pkg"
>>"%CFG%" echo -LN"%OUT%\pkg\dcp"
>>"%CFG%" echo -$D+
>>"%CFG%" echo -$L+
>>"%CFG%" echo -$Y+
>>"%CFG%" echo -DDEBUG

pushd "%OUT%\pkg"
echo --- package: FNCCadSysVCL.dpk >> "%LOG%"
echo --- dcc32 config: >> "%LOG%"
type "%CFG%" >> "%LOG%"
%DCC% -B "%ROOT%\Packages\delphi\FNCCadSysVCL.dpk" >> "%LOG%" 2>&1
set VCLERR=%ERRORLEVEL%
echo === dcc32 exit %VCLERR% >> "%LOG%"
popd

rem --- FMX -------------------------------------------------------------
rem CADSYS_FMX on the command line, because the dpk relies on the dproj
rem to define it and dcc32 never reads the dproj. FMX namespaces and
rem not the Vcl ones, so a bare Graphics or Controls cannot quietly
rem resolve to a VCL unit - the same rule as build-fmx.cmd.
> "%CFG%" echo -U"%BDSROOT%lib\Win32\release;%DCPDIR%;%ROOT%\Generated\FMX;%FNCCORE%"
>>"%CFG%" echo -I"%BDSROOT%lib\Win32\release;%ROOT%\Generated\FMX"
>>"%CFG%" echo -R"%BDSROOT%lib\Win32\release;%ROOT%\Generated\FMX;%ROOT%\Packages\delphi"
>>"%CFG%" echo -O"%BDSROOT%lib\Win32\release"
>>"%CFG%" echo -NSSystem;Xml;Data;Datasnap;Web;Soap;FMX;Winapi;System.Win
>>"%CFG%" echo -N0"%OUT%\pkg\dcu-fmx"
>>"%CFG%" echo -LE"%OUT%\pkg"
>>"%CFG%" echo -LN"%OUT%\pkg\dcp"
>>"%CFG%" echo -$D+
>>"%CFG%" echo -$L+
>>"%CFG%" echo -$Y+
>>"%CFG%" echo -DDEBUG;CADSYS_FMX

pushd "%OUT%\pkg"
echo. >> "%LOG%"
echo --- package: FNCCadSysFMX.dpk >> "%LOG%"
echo --- dcc32 config: >> "%LOG%"
type "%CFG%" >> "%LOG%"
%DCC% -B "%ROOT%\Packages\delphi\FNCCadSysFMX.dpk" >> "%LOG%" 2>&1
set FMXERR=%ERRORLEVEL%
echo === dcc32 exit %FMXERR% >> "%LOG%"
popd

rem --- design-time, one per framework ----------------------------------
rem Two of them, because Delphi keys its component registry by class name
rem globally and both frameworks declare the same class names - which is
rem the point of the port. One package registering both raises EFilerError
rem at install. TMS FNC has the same situation and answers it the same
rem way: install the framework you are working in.
for %%k in (VCL FMX) do (
  > "%CFG%" echo -U"%BDSROOT%lib\Win32\release;%DCPDIR%;%OUT%\pkg\dcp;%ROOT%\Generated\%%k;%FNCCORE%"
  >>"%CFG%" echo -I"%BDSROOT%lib\Win32\release;%ROOT%\Generated\%%k"
  >>"%CFG%" echo -R"%BDSROOT%lib\Win32\release;%ROOT%\Packages\delphi"
  >>"%CFG%" echo -O"%BDSROOT%lib\Win32\release"
  >>"%CFG%" echo -NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win
  >>"%CFG%" echo -N0"%OUT%\pkg\dcu-de-%%k"
  >>"%CFG%" echo -LE"%OUT%\pkg"
  >>"%CFG%" echo -LN"%OUT%\pkg\dcp"
  >>"%CFG%" echo -$D+
  >>"%CFG%" echo -$L+
  >>"%CFG%" echo -$Y+
  >>"%CFG%" echo -DDEBUG
  if not exist "%OUT%\pkg\dcu-de-%%k" mkdir "%OUT%\pkg\dcu-de-%%k"
  pushd "%OUT%\pkg"
  echo. >> "%LOG%"
  echo --- package: FNCCadSysDE%%k.dpk >> "%LOG%"
  echo --- dcc32 config: >> "%LOG%"
  type "%CFG%" >> "%LOG%"
  %DCC% -B "%ROOT%\Packages\delphi\FNCCadSysDE%%k.dpk" >> "%LOG%" 2>&1
  if errorlevel 1 set DEERR=1
  echo === dcc32 finished FNCCadSysDE%%k >> "%LOG%"
  popd
)

if not "%VCLERR%"=="0" (
  echo VCL PACKAGE FAILED - see Tools\logs\build-packages.log
)
if not "%FMXERR%"=="0" (
  echo FMX PACKAGE FAILED - see Tools\logs\build-packages.log
)
if not "%DEERR%"=="0" (
  echo A DESIGN-TIME PACKAGE FAILED - see Tools\logs\build-packages.log
)
if not "%VCLERR%"=="0" exit /b %VCLERR%
if not "%FMXERR%"=="0" exit /b %FMXERR%
if not "%DEERR%"=="0" exit /b %DEERR%

echo PACKAGES OK - nothing installed. Built into Tools\build\pkg:
for %%f in ("%OUT%\pkg\*.bpl") do echo   %%~nxf
echo.
echo This is a compile check. The IDE does not search that folder, so to
echo install, open the four .dproj files in the IDE - which write to the
echo IDE's own Bpl folder - and build them in this order:
echo.
echo   1. FNCCadSysVCL      runtime, VCL     build only
echo   2. FNCCadSysFMX      runtime, FMX     build only
echo   3. FNCCadSysDEVCL    design-time      build, then install
echo   4. FNCCadSysDEFMX    design-time      build, then install
echo.
echo The order matters and nothing warns about it: the runtime packages
echo carry the classes and the design-time ones only reference them, so a
echo DE package installed against a stale runtime bpl fails in ways that
echo do not name the cause.
exit /b 0
