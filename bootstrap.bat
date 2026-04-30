@echo off
setlocal EnableDelayedExpansion
set "WORKSPACE_ROOT=%~dp0"
set "WORKSPACE_ROOT=%WORKSPACE_ROOT:~0,-1%"
if not defined DEVECO_STUDIO_PATH set "DEVECO_STUDIO_PATH=C:\Program Files\Huawei\DevEco Studio"
if not exist "%DEVECO_STUDIO_PATH%" (
  echo [ENV_001] DevEco Studio not found: %DEVECO_STUDIO_PATH% ^| Install DevEco Studio or set DEVECO_STUDIO_PATH.
  exit /b 1
)
call "%WORKSPACE_ROOT%\start-simulator.bat"
if errorlevel 1 exit /b 1
call "%WORKSPACE_ROOT%\workspace-build.bat"
if errorlevel 1 exit /b 1
call "%WORKSPACE_ROOT%\workspace-start.bat" --app app-center
call "%WORKSPACE_ROOT%\workspace-status.bat"
exit /b %errorlevel%
