@echo off
set "APP_ROOT=%~dp0.."
for %%I in ("%APP_ROOT%") do set "APP_ROOT=%%~fI"
set "WORKSPACE_ROOT=%APP_ROOT%\.."
for %%I in ("%WORKSPACE_ROOT%") do set "WORKSPACE_ROOT=%%~fI"
call "%WORKSPACE_ROOT%\scripts\common.bat" %*
