@echo off
setlocal EnableDelayedExpansion

set CHIP_ALLOW_PRIVATE_ACCESS=-version=CHIP_ALLOW_PRIVATE_ACCESS
rdmd -I..\..\src %CHIP_ALLOW_PRIVATE_ACCESS% main.d
