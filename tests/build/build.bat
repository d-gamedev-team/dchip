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
rem CHIP_ALLOW_PRIVATE_ACCESS
rem     - Make private fields public.
rem
rem CHIP_ENABLE_WARNINGS
rem     - Enable internal warnings.
rem
rem CHIP_USE_DOUBLES
rem     - Use double-precision floating point internally.

rem set CHIP_ENABLE_UNITTESTS=-version=CHIP_ENABLE_UNITTESTS
set CHIP_ALLOW_PRIVATE_ACCESS=-version=CHIP_ALLOW_PRIVATE_ACCESS
rem set CHIP_ENABLE_WARNINGS=-version=CHIP_ENABLE_WARNINGS
rem set CHIP_USE_DOUBLES=-version=CHIP_USE_DOUBLES
set USE_DEIMOS_GLFW=-version=USE_DEIMOS_GLFW

set includes=-I..\src -Ilib
set implibs=lib\glfw3_implib.lib

set version_flags=%USE_DEIMOS_GLFW% %USE_DCHIP% %CHIP_ENABLE_UNITTESTS% %CHIP_ALLOW_PRIVATE_ACCESS% %CHIP_ENABLE_WARNINGS% %CHIP_USE_DOUBLES%

rem Note: 2.063.2 can't use -O (gets stuck),
rem and can't use -inline (errors about nested functions)
set optimizations=-release -noboundscheck
set flags=%includes% %implibs% %version_flags% %optimizations% -g -w

rem set PATH=C:\ldc\bin;%PATH%
rem set PATH=C:\GDC\bin;C:\dev\projects\GDMD;%PATH%

rem Note: You might have to pass --force to pick this up due to some RDMD bug
rem set compiler=--compiler=gdmd
set compiler=--compiler=dmd.exe
rem set compiler=--compiler=dmd_msc.exe
rem set compiler=--compiler=ldmd2.exe

set FileName=%1
set SourceFile=%2

set main_file=%SourceFile%

set "build_app=rdmd --force -m32 -of%bin_path%\%FileName%.exe %compiler% %flags% %main_file%"

%build_app%
