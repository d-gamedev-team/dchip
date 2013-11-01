@echo off
setlocal EnableDelayedExpansion

set CHIP_ALLOW_PRIVATE_ACCESS=-version=CHIP_ALLOW_PRIVATE_ACCESS

rem Note: -O seems to be broken
rem set OPTIMIZE_FLAGS=-release -inline -noboundscheck
rdmd -I..\..\src %OPTIMIZE_FLAGS% %CHIP_ALLOW_PRIVATE_ACCESS% main.d
