@echo off
setlocal EnableDelayedExpansion
set "WORKSPACE_ROOT=%~dp0"
set "WORKSPACE_ROOT=%WORKSPACE_ROOT:~0,-1%"
set "TARGET_APP=app-center"

:args
if "%~1"=="" goto run
if "%~1"=="--app" set "TARGET_APP=%~2" & shift & shift & goto args
if "%~1"=="--skip" shift & shift & goto args
if "%~1"=="--force" shift & goto args
if "%~1"=="--help" echo Usage: workspace-start.bat [--app name] [--skip name] [--force] & exit /b 0
echo Unknown argument: %~1
exit /b 1

:run
set "APP_ROOT=%WORKSPACE_ROOT%\%TARGET_APP%"
call "%WORKSPACE_ROOT%\scripts\common.bat" :start_dev
exit /b %errorlevel%
