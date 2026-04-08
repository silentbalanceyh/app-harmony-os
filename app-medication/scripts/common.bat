@echo off
setlocal EnableDelayedExpansion

rem ============================================================
rem Common functions for HarmonyOS app development (Windows)
rem Architecture: This file CALLs itself with function name as arg
rem Usage: call common.bat :function_name [args...]
rem ============================================================

rem Initialize paths first (always run on first call)
set "SCRIPTS_ROOT=%~dp0"
set "SCRIPTS_ROOT=%SCRIPTS_ROOT:~0,-1%"
for %%i in ("%SCRIPTS_ROOT%") do set "APP_ROOT=%%~dpi"
set "APP_ROOT=%APP_ROOT:~0,-1%"
for %%i in ("%APP_ROOT%") do set "APP_NAME=%%~ni"
set "APP_CONFIG=%APP_ROOT%\app.json"
for %%i in ("%APP_ROOT%") do set "WORKSPACE_ROOT=%%~dpi"
set "WORKSPACE_ROOT=%WORKSPACE_ROOT:~0,-1%"
set "SIMULATOR_SCRIPT=%WORKSPACE_ROOT%\start-simulator.bat"

rem DevEco Studio paths
if not defined DEVECO_STUDIO_PATH set "DEVECO_STUDIO_PATH=C:\Program Files\Huawei\DevEco Studio"
set "DEVECO_NODE_HOME=%DEVECO_STUDIO_PATH%\tools\node"
set "DEVECO_HVIGORW=%DEVECO_STUDIO_PATH%\tools\hvigor\bin\hvigorw.bat"
set "DEVECO_HDC=%DEVECO_STUDIO_PATH%\sdk\default\openharmony\toolchains\hdc.exe"
set "DEVECO_SDK_ROOT=%DEVECO_STUDIO_PATH%\sdk\default"

rem Set Node.js environment for hvigor (use DevEco bundled Node)
set "NODE_HOME=%DEVECO_NODE_HOME%"
set "PATH=%NODE_HOME%;%PATH%"

rem If called with a function label, jump to it
set "FUNC_CALL=%~1"
if defined FUNC_CALL (
    if "!FUNC_CALL!" neq "" (
        if "!FUNC_CALL:~0,1!"==":" (
            shift
            goto !FUNC_CALL!
        )
    )
)

rem Default: just initialize and return
exit /b 0

rem ============================================================
rem Functions
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

:run_hdc
where hdc >nul 2>nul
if not errorlevel 1 (
    hdc %*
    set "_hdc_err=!errorlevel!"
    exit /b !_hdc_err!
)
if exist "%DEVECO_HDC%" (
    "%DEVECO_HDC%" %*
    set "_hdc_err=!errorlevel!"
    exit /b !_hdc_err!
)
call :error "hdc command not found"
exit /b 1

:list_targets
call :run_hdc list targets
exit /b %errorlevel%

:check_device
call :info "Checking device connection..."
set "_targets="
rem Use direct hdc path in for loop (subshell can't see script functions)
set "_hdc_cmd="
where hdc >nul 2>nul
if not errorlevel 1 (
    set "_hdc_cmd=hdc"
) else if exist "%DEVECO_HDC%" (
    set "_hdc_cmd=%DEVECO_HDC%"
)
if not defined _hdc_cmd (
    call :error "hdc command not found"
    exit /b 1
)
for /f "usebackq delims=" %%i in (`"%_hdc_cmd%" list targets 2^>nul`) do (
    set "_line=%%i"
    if "!_line!" neq "[Fail]" if "!_line!" neq "[Empty]" if "!_line!" neq "" (
        set "_targets=!_targets! !_line!"
    )
)
if not defined _targets (
    call :error "No HarmonyOS device connected"
    exit /b 1
)
call :ok "Device connected"
exit /b 0

:ensure_simulator
if not exist "%SIMULATOR_SCRIPT%" (
    call :error "Simulator script not found"
    exit /b 1
)
call "%SIMULATOR_SCRIPT%"
exit /b %errorlevel%

:build
set "_mode=%~2"
if "%_mode%"=="" set "_mode=debug"
call :info "Building %APP_NAME% (%_mode%)..."

rem Find hvigorw
set "_hvigor="
if exist "%APP_ROOT%\hvigorw.bat" set "_hvigor=%APP_ROOT%\hvigorw.bat"
if exist "%APP_ROOT%\hvigorw" set "_hvigor=%APP_ROOT%\hvigorw"
if not defined _hvigor if exist "%DEVECO_HVIGORW%" set "_hvigor=%DEVECO_HVIGORW%"
if not defined _hvigor (
    call :error "hvigorw not found"
    exit /b 1
)

pushd "%APP_ROOT%"
if "%_mode%"=="debug" (
    call "!_hvigor!" assembleApp -p product=default -p buildMode=debug
) else (
    call "!_hvigor!" assembleApp -p product=default -p buildMode=release
)
popd
exit /b %errorlevel%

:find_hap
set "_hap="
for /f "usebackq delims=" %%i in (`dir /s /b "%APP_ROOT%\*.hap" 2^>nul`) do (
    set "_hap=%%i"
)
if defined _hap (
    echo !_hap!
)
exit /b 0

:install
set "_hap="
rem Use direct dir command in for loop (subshell can't see script functions)
rem First try to find signed HAP
for /f "usebackq delims=" %%i in (`dir /s /b "%APP_ROOT%\entry\build\default\outputs\default\*-signed.hap" 2^>nul`) do (
    set "_hap=%%i"
)
rem If no signed HAP, find any HAP that's not unsigned
if not defined _hap (
    for /f "usebackq delims=" %%i in (`dir /s /b "%APP_ROOT%\entry\build\default\outputs\default\*.hap" 2^>nul ^| findstr /v "unsigned"`) do (
        set "_hap=%%i"
    )
)
if not defined _hap (
    call :error "No HAP found, build first"
    exit /b 1
)
call :info "Installing: !_hap!"
call :run_hdc install "!_hap!"
exit /b !_hdc_err!

:launch
call :info "Launching %APP_NAME%..."

rem Read bundleName and abilityName from app.json
set "_bundle="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-Content -Raw '%APP_CONFIG%' | ConvertFrom-Json).bundleName"`) do (
    set "_bundle=%%i"
)
set "_ability="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-Content -Raw '%APP_CONFIG%' | ConvertFrom-Json).abilityName"`) do (
    set "_ability=%%i"
)

if not defined _bundle (
    call :error "Missing bundleName in app.json"
    exit /b 1
)
if not defined _ability (
    call :error "Missing abilityName in app.json"
    exit /b 1
)

call :run_hdc shell aa start -a "%_ability%" -b "%_bundle%"
exit /b %errorlevel%

:stop
tasklist | findstr /I "hvigor" >nul 2>nul
if not errorlevel 1 (
    taskkill /F /IM hvigor* >nul 2>nul
    call :ok "Stopped hvigor processes"
) else (
    call :info "No hvigor processes"
)
exit /b 0

:start_dev
call :ensure_simulator
if errorlevel 1 exit /b 1
call :build debug
if errorlevel 1 exit /b 1
call :check_device
if errorlevel 1 exit /b 1
call :install
if errorlevel 1 exit /b 1
call :launch
call :ok "Dev start completed for %APP_NAME%"
exit /b 0

:start_release
call :ensure_simulator
if errorlevel 1 exit /b 1
call :build release
if errorlevel 1 exit /b 1
call :check_device
if errorlevel 1 exit /b 1
call :install
if errorlevel 1 exit /b 1
call :launch
call :ok "Release start completed for %APP_NAME%"
exit /b 0

:build_only
call :build debug
exit /b %errorlevel%