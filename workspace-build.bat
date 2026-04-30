@echo off
setlocal EnableDelayedExpansion
set "WORKSPACE_ROOT=%~dp0"
set "WORKSPACE_ROOT=%WORKSPACE_ROOT:~0,-1%"
set "TARGET_APP="

:args
if "%~1"=="" goto run
if "%~1"=="--app" set "TARGET_APP=%~2" & shift & shift & goto args
if "%~1"=="--skip" shift & shift & goto args
if "%~1"=="--force" shift & goto args
if "%~1"=="--help" echo Usage: workspace-build.bat [--app name] [--skip name] [--force] & exit /b 0
echo Unknown argument: %~1
exit /b 1

:run
if defined TARGET_APP (
  call :build_one "%TARGET_APP%"
) else (
  if exist "%WORKSPACE_ROOT%\app-center\app.json" call :build_one app-center
  for /d %%A in ("%WORKSPACE_ROOT%\app-*") do if /I not "%%~nxA"=="app-center" if exist "%%A\app.json" call :build_one "%%~nxA"
)
exit /b %errorlevel%

:build_one
set "APP_ROOT=%WORKSPACE_ROOT%\%~1"
call "%WORKSPACE_ROOT%\scripts\common.bat" :build_only
exit /b %errorlevel%
