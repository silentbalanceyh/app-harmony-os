@echo off
setlocal EnableDelayedExpansion
set "WORKSPACE_ROOT=%~dp0"
set "WORKSPACE_ROOT=%WORKSPACE_ROOT:~0,-1%"
echo Workspace: %WORKSPACE_ROOT%
if defined DEVECO_STUDIO_PATH (
  echo DevEco: %DEVECO_STUDIO_PATH%
) else (
  echo DevEco: C:\Program Files\Huawei\DevEco Studio
)
echo Apps:
if exist "%WORKSPACE_ROOT%\app-center\app.json" echo   - app-center
for /d %%A in ("%WORKSPACE_ROOT%\app-*") do if /I not "%%~nxA"=="app-center" if exist "%%A\app.json" echo   - %%~nxA
call "%WORKSPACE_ROOT%\scripts\common.bat" :run_hdc list targets
exit /b 0
