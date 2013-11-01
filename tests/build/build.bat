@echo off
setlocal EnableDelayedExpansion

set thisPath=%~dp0
set dtkRoot=%thisPath%\..\..
set bin_path=%thisPath%\..\bin
set srcDir=%dtkRoot%\src
cd %thisPath%\..

if [%1]==[] goto :error
if [%2]==[] goto :error
goto :next

:error
echo Error: Must pass project name and source name as arguments.
goto :eof

:next

rem Version options
rem ---------------
rem
rem CHIP_ENABLE_UNITTESTS
rem     - Enable unittest blocks.
rem       By default unittest blocks are not compiled-in,
rem       leading to huge savings in compilation time.
rem       Note: The -unittest flag still needs to be
rem       passed to run the tests.
rem
rem CHIP_ALLOW_PRIVATE_ACCESS
rem     - Make private fields public.
rem
rem CHIP_ENABLE_WARNINGS
rem     - Enable internal warnings.
rem
rem CHIP_USE_DOUBLES
rem     - Use double-precision floating point internally.

rem set CHIP_ENABLE_UNITTESTS=-version=CHIP_ENABLE_UNITTESTS
rem set CHIP_ALLOW_PRIVATE_ACCESS=-version=CHIP_ALLOW_PRIVATE_ACCESS
set CHIP_ENABLE_WARNINGS=-version=CHIP_ENABLE_WARNINGS
rem set CHIP_USE_DOUBLES=-version=CHIP_USE_DOUBLES

set includes=-I..\src
set version_flags=%CHIP_ENABLE_UNITTESTS% %CHIP_ALLOW_PRIVATE_ACCESS% %CHIP_ENABLE_WARNINGS% %CHIP_USE_DOUBLES%
set flags=%includes% %version_flags% -g -w

set compiler=dmd.exe
rem set compiler=dmd_msc.exe
rem set compiler=ldmd2.exe

set FileName=%1
set SourceFile=%2

set main_file=%SourceFile%

set "build_app=rdmd --force -of%bin_path%\%FileName%.exe --compiler=%compiler% %flags% %main_file%"

%build_app%
