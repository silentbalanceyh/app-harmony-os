@echo off
setlocal EnableDelayedExpansion
set "WORKSPACE_ROOT=%~dp0"
set "WORKSPACE_ROOT=%WORKSPACE_ROOT:~0,-1%"
call "%WORKSPACE_ROOT%\scripts\simulator.bat" :ensure_simulator
exit /b %errorlevel%
