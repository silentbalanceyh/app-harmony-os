@echo off
setlocal EnableDelayedExpansion

rem HarmonyOS Simulator Bootstrap Script for Windows
rem Checks connectivity and optionally starts DevEco emulator

rem Skip to main execution, functions are defined below
goto :main

rem ============================================================
rem Function Definitions
rem ============================================================

:info
echo [INFO]  %*
goto :eof

:warn
echo [WARN]  %*
goto :eof

:error
echo [ERROR] %*
goto :eof

:ok
echo [OK]    %*
goto :eof

:require_executable
set "check_path=%~1"
set "check_name=%~2"
if not exist "%check_path%" (
    call :error "%check_name% not found: %check_path%"
    exit /b 1
)
exit /b 0

:list_connected_targets
set "raw_targets="
"%DEVECO_HDC%" list targets 2>nul >nul
if errorlevel 1 (
    exit /b 0
)
for /f "usebackq tokens=*" %%i in (`"%DEVECO_HDC%" list targets 2^>nul`) do (
    set "line=%%i"
    if "!line!" neq "[Fail]" (
        if "!line!" neq "[Empty]" (
            if "!line!" neq "" (
                echo !line!
            )
        )
    )
)
exit /b 0

:list_emulator_instances
"%DEVECO_EMULATOR%" -list 2>nul
exit /b 0

:pick_emulator_instance
if defined EMULATOR_NAME (
    echo %EMULATOR_NAME%
    exit /b 0
)
for /f "usebackq tokens=*" %%i in (`"%DEVECO_EMULATOR%" -list 2^>nul`) do (
    set "first_instance=%%i"
    if "!first_instance!" neq "" (
        echo !first_instance!
        exit /b 0
    )
)
exit /b 0

:wait_for_connection_once
set "wait_seconds=%~1"
if "%wait_seconds%"=="" set "wait_seconds=1"
set "targets="
for /f "usebackq tokens=*" %%i in (`"%DEVECO_HDC%" list targets 2^>nul`) do (
    set "targets=!targets!%%i"
)
if defined targets (
    if "!targets!" neq "" (
        if "!targets!" neq "[Empty]" (
            if "!targets!" neq "[Fail]" (
                exit /b 0
            )
        )
    )
)
ping -n %wait_seconds% 127.0.0.1 >nul 2>nul
exit /b 1

rem ============================================================
rem Main Execution
rem ============================================================

:main

rem Environment variables with defaults
set "WORKSPACE_ROOT=%~dp0"
set "WORKSPACE_ROOT=%WORKSPACE_ROOT:~0,-1%"

if not defined DEVECO_STUDIO_PATH set "DEVECO_STUDIO_PATH=C:\Program Files\Huawei\DevEco Studio"
if not defined DEVECO_SDK_ROOT set "DEVECO_SDK_ROOT=%DEVECO_STUDIO_PATH%\sdk"
set "DEVECO_HDC=%DEVECO_STUDIO_PATH%\sdk\default\openharmony\toolchains\hdc.exe"
set "DEVECO_EMULATOR=%DEVECO_STUDIO_PATH%\tools\emulator\Emulator.exe"

if not defined EMULATOR_INSTANCE_PATH set "EMULATOR_INSTANCE_PATH=%USERPROFILE%\.Huawei\Emulator\deployed"
if not defined EMULATOR_IMAGE_ROOT set "EMULATOR_IMAGE_ROOT=%USERPROFILE%\.Huawei\Sdk"
set "LOG_DIR=%WORKSPACE_ROOT%\.logs"
set "LOG_FILE=%LOG_DIR%\simulator-start.log"

if not defined AUTO_START_EMULATOR set "AUTO_START_EMULATOR=true"

rem Check executables
call :info "Checking DevEco tools..."
call :require_executable "%DEVECO_HDC%" "hdc"
if errorlevel 1 (
    call :error "Please set DEVECO_STUDIO_PATH to your DevEco installation directory"
    exit /b 1
)

call :require_executable "%DEVECO_EMULATOR%" "Emulator"
if errorlevel 1 (
    call :error "Please set DEVECO_STUDIO_PATH to your DevEco installation directory"
    exit /b 1
)

rem Check if already connected
call :info "Checking for connected HarmonyOS device..."
set "already_connected="
for /f "usebackq tokens=*" %%i in (`"%DEVECO_HDC%" list targets 2^>nul`) do (
    set "connected_line=%%i"
    if "!connected_line!" neq "[Empty]" (
        if "!connected_line!" neq "[Fail]" (
            if "!connected_line!" neq "" (
                set "already_connected=yes"
            )
        )
    )
)

if defined already_connected (
    call :ok "HarmonyOS simulator/device already connected"
    exit /b 0
)

if "%AUTO_START_EMULATOR%" neq "true" (
    call :error "No HarmonyOS simulator/device connected"
    exit /b 1
)

rem Get emulator name
call :info "Looking for emulator instance..."
for /f "usebackq tokens=*" %%i in (`"%DEVECO_EMULATOR%" -list 2^>nul`) do (
    set "emulator_name=%%i"
    goto :got_emulator_name
)

:got_emulator_name
if not defined emulator_name (
    call :error "No local DevEco simulator instance found"
    call :error "Create an emulator in DevEco Device Manager first"
    exit /b 1
)

rem Create log directory
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

rem Build emulator command
set "emu_cmd=%DEVECO_EMULATOR% -hvd %emulator_name%"
if defined EMULATOR_INSTANCE_PATH (
    set "emu_cmd=%emu_cmd% -path %EMULATOR_INSTANCE_PATH%"
)
set "emu_cmd=%emu_cmd% -t trace_%RANDOM%_commandPipe"
if defined EMULATOR_IMAGE_ROOT (
    set "emu_cmd=%emu_cmd% -imageRoot %EMULATOR_IMAGE_ROOT%"
)
if defined EMULATOR_HDC_PORT (
    set "emu_cmd=%emu_cmd% -hdcport %EMULATOR_HDC_PORT%"
)

call :info "Starting emulator: %emulator_name%"
call :info "Log file: %LOG_FILE%"

rem Start emulator in background
start /b "" %emu_cmd% >"%LOG_FILE%" 2>&1

rem Wait for connection (5 attempts, 1 second each)
set "attempt=1"
:wait_loop_1
if %attempt% gtr 5 goto :wait_phase_2
call :wait_for_connection_once 1
if not errorlevel 1 (
    call :ok "HarmonyOS simulator connected"
    exit /b 0
)
set /a attempt+=1
goto :wait_loop_1

:wait_phase_2
rem Wait longer (20 attempts, 2 seconds each)
call :info "Waiting longer for emulator startup..."
set "attempt=1"
:wait_loop_2
if %attempt% gtr 20 goto :wait_timeout
call :wait_for_connection_once 2
if not errorlevel 1 (
    call :ok "HarmonyOS simulator connected"
    exit /b 0
)
set /a attempt+=1
goto :wait_loop_2

:wait_timeout
call :warn "Automatic simulator start did not connect within timeout"
call :warn "Check simulator log: %LOG_FILE%"
call :error "No HarmonyOS simulator/device connected"
exit /b 1