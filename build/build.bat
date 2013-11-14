@echo off
setlocal EnableDelayedExpansion

rem Build options
rem -------------
set do_build_tests=1
set do_run_tests=1
set do_build_lib=1

set this_path=%~dp0
set dchip_root=%this_path%\..
set build_path=%this_path%
set bin_path=%dchip_root%\bin
set lib_path=%dchip_root%\lib
cd %this_path%\..\src

rem Version options
rem ---------------
rem CHIP_ALLOW_PRIVATE_ACCESS
rem     - Make private fields public.
rem
rem CHIP_ENABLE_WARNINGS
rem     - Enable internal warnings.
rem
rem CHIP_USE_DOUBLES
rem     - Use double-precision floating point internally.

if [%build_tests%]==[] goto :NEXT
:NEXT
rem set CHIP_ALLOW_PRIVATE_ACCESS=-version=CHIP_ALLOW_PRIVATE_ACCESS
rem set CHIP_ENABLE_WARNINGS=-version=CHIP_ENABLE_WARNINGS
set CHIP_USE_DOUBLES=-version=CHIP_USE_DOUBLES

set includes=-I%cd%
set version_flags=%CHIP_ALLOW_PRIVATE_ACCESS% %CHIP_ENABLE_WARNINGS% %CHIP_USE_DOUBLES%
set flags=%includes% %version_flags% -g -w

set compiler=dmd.exe
rem set compiler=dmd_msc.exe
rem set compiler=ldmd2.exe

set main_file=dchip\all.d
rem set main_file=dchip\package.d

set "build_tests=rdmd --force --build-only -of%bin_path%\dchip_test.exe --main -unittest --compiler=%compiler% %flags% %main_file%"

set stdout_log=%build_path%\dchiptest_stdout.log
set stderr_log=%build_path%\dchiptest_stderr.log

rem Clean up the logs
type NUL > %stdout_log%
type NUL > %stderr_log%

if [%do_build_tests%]==[] goto :BUILD

:TEST

timeit %build_tests%
if errorlevel 1 GOTO :ERROR
if [%do_run_tests%]==[] (
    echo Success: dchip tests built. >> %stdout_log%
    type %stdout_log%
    type NUL > %stdout_log%
)

if [%do_run_tests%]==[] goto :BUILD

%bin_path%\dchip_test.exe
if errorlevel 1 GOTO :ERROR

echo Success: dchip tests passed. >> %stdout_log%
type %stdout_log%
type NUL > %stdout_log%

:BUILD

if [%do_build_lib%]==[] goto :eof

set "files="
for /r %%i in (*.d) do (
    if [%%i] neq [%cd%\dchip\package.d] set files=!files! %%i
)

%compiler% -of%bin_path%\dchip.lib -lib %flags% %files%
if errorlevel 1 GOTO :eof

echo Success: dchip built. >> %stdout_log%
type %stdout_log%
goto :eof

:ERROR
echo. >> %stderr_log%
echo Failure: dchip tests failed. >> %stderr_log%
type %stderr_log%
goto :eof
