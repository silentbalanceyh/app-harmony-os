@echo off
setlocal EnableDelayedExpansion
set "WORKSPACE_ROOT=%~dp0.."
for %%I in ("%WORKSPACE_ROOT%") do set "WORKSPACE_ROOT=%%~fI"
set "TARGET_APP="
set "ALL="
set "DEEP="

:args
if "%~1"=="" goto run
if "%~1"=="--help" goto help
if "%~1"=="--app" set "TARGET_APP=%~2" & shift & shift & goto args
if "%~1"=="--all" set "ALL=1" & shift & goto args
if "%~1"=="--deep" set "DEEP=1" & shift & goto args
echo Unknown argument: %~1
exit /b 1

:help
echo Usage: scripts\clean-build.bat [--app app-name] [--all] [--deep]
exit /b 0

:run
if defined TARGET_APP (
  call :clean_one "%TARGET_APP%"
) else (
  for /d %%A in ("%WORKSPACE_ROOT%\app-*") do if exist "%%A\app.json" call :clean_one "%%~nxA"
)
if defined DEEP if exist "%WORKSPACE_ROOT%\.hvigor-cache" rmdir /s /q "%WORKSPACE_ROOT%\.hvigor-cache"
exit /b 0

:clean_one
set "APP=%~1"
set "ROOT=%WORKSPACE_ROOT%\%APP%"
if exist "%ROOT%\build" rmdir /s /q "%ROOT%\build"
if exist "%ROOT%\entry\build" rmdir /s /q "%ROOT%\entry\build"
echo [OK]    Cleaned build outputs for %APP%
if defined DEEP (
  if exist "%ROOT%\.hvigor" rmdir /s /q "%ROOT%\.hvigor"
  if exist "%ROOT%\.deveco-sdk-shim" rmdir /s /q "%ROOT%\.deveco-sdk-shim"
)
exit /b 0
