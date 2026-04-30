@echo off
setlocal EnableDelayedExpansion

set "SCRIPTS_ROOT=%~dp0"
set "SCRIPTS_ROOT=%SCRIPTS_ROOT:~0,-1%"
for %%I in ("%SCRIPTS_ROOT%\..") do set "APP_ROOT=%%~fI"
for %%I in ("%APP_ROOT%\..") do set "WORKSPACE_ROOT=%%~fI"
set "WORKSPACE_COMMON=%WORKSPACE_ROOT%\scripts\common.bat"

if not exist "%WORKSPACE_COMMON%" (
    echo [ERROR] Workspace common script not found: %WORKSPACE_COMMON%
    exit /b 1
)

call "%WORKSPACE_COMMON%" %*
exit /b %errorlevel%
