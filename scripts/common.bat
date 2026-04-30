@echo off
setlocal EnableDelayedExpansion

if not defined WORKSPACE_ROOT (
  set "WORKSPACE_ROOT=%~dp0.."
  for %%I in ("!WORKSPACE_ROOT!") do set "WORKSPACE_ROOT=%%~fI"
)
if not defined APP_ROOT (
  for %%I in ("%~dp0..") do set "APP_ROOT=%%~fI"
)
for %%I in ("!APP_ROOT!") do set "APP_NAME=%%~nxI"
set "APP_CONFIG=!APP_ROOT!\app.json"
if not defined DEVECO_STUDIO_PATH set "DEVECO_STUDIO_PATH=C:\Program Files\Huawei\DevEco Studio"
set "DEVECO_HDC=%DEVECO_STUDIO_PATH%\sdk\default\openharmony\toolchains\hdc.exe"
set "DEVECO_HVIGORW=%DEVECO_STUDIO_PATH%\tools\hvigor\bin\hvigorw.bat"
set "DEVECO_SDK_ROOT=%DEVECO_STUDIO_PATH%\sdk\default"

set "FUNC=%~1"
if defined FUNC if "!FUNC:~0,1!"==":" (
  shift
  goto !FUNC!
)
exit /b 0

:info
echo [INFO]  %*
exit /b 0

:warn
echo [WARN]  %*
exit /b 0

:error
echo [ERROR] %*
exit /b 1

:ok
echo [OK]    %*
exit /b 0

:run_hdc
where hdc >nul 2>nul
if not errorlevel 1 (
  hdc %*
  exit /b !errorlevel!
)
if exist "%DEVECO_HDC%" (
  "%DEVECO_HDC%" %*
  exit /b !errorlevel!
)
echo [ENV_001] hdc command not found ^| Install DevEco Studio or add hdc to PATH.
exit /b 1

:ensure_simulator
call "%WORKSPACE_ROOT%\scripts\simulator.bat" :ensure_simulator
exit /b %errorlevel%

:check_device
set "connected="
for /f "usebackq delims=" %%T in (`"%DEVECO_HDC%" list targets 2^>nul`) do (
  if not "%%T"=="[Empty]" if not "%%T"=="[Fail]" if not "%%T"=="" set "connected=1"
)
if not defined connected (
  echo [ENV_003] No HarmonyOS device connected ^| Start a simulator or connect hardware.
  exit /b 1
)
echo [OK]    Device connected
exit /b 0

:find_hvigor
set "_hvigor="
if exist "%APP_ROOT%\hvigorw.bat" set "_hvigor=%APP_ROOT%\hvigorw.bat"
if not defined _hvigor if exist "%APP_ROOT%\hvigorw" set "_hvigor=%APP_ROOT%\hvigorw"
if not defined _hvigor if exist "%DEVECO_HVIGORW%" set "_hvigor=%DEVECO_HVIGORW%"
if not defined _hvigor (
  echo [ENV_001] hvigorw not found ^| Install DevEco Studio or restore the app wrapper.
  exit /b 1
)
exit /b 0

:build
set "_mode=%~1"
if "%_mode%"=="" set "_mode=debug"
call :find_hvigor
if errorlevel 1 exit /b 1
echo [INFO]  Building %APP_NAME% (%_mode%)...
pushd "%APP_ROOT%"
if /I "%_mode%"=="release" (
  call "!_hvigor!" assembleApp -p product=default -p buildMode=release
) else (
  call "!_hvigor!" assembleApp -p product=default -p buildMode=debug
)
set "_err=!errorlevel!"
popd
if not "%_err%"=="0" echo [BUILD_001] Build failed for %APP_NAME% ^| Check hvigor output above.
exit /b %_err%

:find_hap
set "_hap="
for /f "usebackq delims=" %%H in (`dir /s /b "%APP_ROOT%\*.hap" 2^>nul ^| findstr /v /i "unsigned"`) do set "_hap=%%H"
if defined _hap echo !_hap!
exit /b 0

:install
set "_hap="
for /f "usebackq delims=" %%H in (`dir /s /b "%APP_ROOT%\*.hap" 2^>nul ^| findstr /v /i "unsigned"`) do set "_hap=%%H"
if not defined _hap (
  echo [DEPLOY_001] No HAP found for %APP_NAME% ^| Build the app first.
  exit /b 1
)
call :check_device
if errorlevel 1 exit /b 1
echo [INFO]  Installing !_hap!
call :run_hdc install "!_hap!"
exit /b %errorlevel%

:launch
for /f "usebackq delims=" %%B in (`python3 -c "import json; print(json.load(open(r'%APP_CONFIG%',encoding='utf-8')).get('bundleName',''))"`) do set "_bundle=%%B"
for /f "usebackq delims=" %%A in (`python3 -c "import json; print(json.load(open(r'%APP_CONFIG%',encoding='utf-8')).get('abilityName',''))"`) do set "_ability=%%A"
if not defined _bundle (
  echo [DEPLOY_002] Missing bundleName in app.json ^| Fix app metadata.
  exit /b 1
)
call :run_hdc shell aa start -a "%_ability%" -b "%_bundle%"
exit /b %errorlevel%

:stop
tasklist | findstr /I "hvigor" >nul 2>nul
if not errorlevel 1 (
  taskkill /F /IM hvigor* >nul 2>nul
  echo [OK]    Stopped hvigor processes
) else (
  echo [INFO]  No hvigor processes
)
exit /b 0

:start_dev
call :ensure_simulator
if errorlevel 1 exit /b 1
call :build debug
if errorlevel 1 exit /b 1
call :install
if errorlevel 1 exit /b 1
call :launch
exit /b %errorlevel%

:start_release
call :ensure_simulator
if errorlevel 1 exit /b 1
call :build release
if errorlevel 1 exit /b 1
call :install
if errorlevel 1 exit /b 1
call :launch
exit /b %errorlevel%

:build_only
call :build debug
exit /b %errorlevel%
