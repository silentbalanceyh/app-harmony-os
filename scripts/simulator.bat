@echo off
setlocal EnableDelayedExpansion

if "%~1"==":ensure_simulator" goto ensure_simulator
exit /b 0

:ensure_simulator
if not defined WORKSPACE_ROOT set "WORKSPACE_ROOT=%~dp0.."
for %%I in ("%WORKSPACE_ROOT%") do set "WORKSPACE_ROOT=%%~fI"
if not defined DEVECO_STUDIO_PATH set "DEVECO_STUDIO_PATH=C:\Program Files\Huawei\DevEco Studio"
set "DEVECO_HDC=%DEVECO_STUDIO_PATH%\sdk\default\openharmony\toolchains\hdc.exe"
set "DEVECO_EMULATOR=%DEVECO_STUDIO_PATH%\tools\emulator\Emulator.exe"
set "LOG_DIR=%WORKSPACE_ROOT%\.logs"
set "LOG_FILE=%LOG_DIR%\simulator-start.log"

if not exist "%DEVECO_HDC%" (
  echo [ENV_001] hdc not found: %DEVECO_HDC% ^| Install DevEco Studio or set DEVECO_STUDIO_PATH.
  exit /b 1
)
if not exist "%DEVECO_EMULATOR%" (
  echo [ENV_001] Emulator not found: %DEVECO_EMULATOR% ^| Install DevEco Studio or set DEVECO_STUDIO_PATH.
  exit /b 1
)

set "connected="
for /f "usebackq delims=" %%T in (`"%DEVECO_HDC%" list targets 2^>nul`) do (
  if not "%%T"=="[Empty]" if not "%%T"=="[Fail]" if not "%%T"=="" set "connected=1"
)
if defined connected (
  echo [OK]    HarmonyOS simulator/device already connected
  exit /b 0
)
if /I "%AUTO_START_EMULATOR%"=="false" (
  echo [ENV_003] No HarmonyOS simulator/device connected ^| Start a simulator or connect hardware.
  exit /b 1
)

for /f "usebackq delims=" %%E in (`"%DEVECO_EMULATOR%" -list 2^>nul`) do (
  set "EMULATOR_NAME=%%E"
  goto got_emulator
)
:got_emulator
if not defined EMULATOR_NAME (
  echo [ENV_003] No local DevEco simulator instance found ^| Create one in DevEco Device Manager.
  exit /b 1
)
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
echo [INFO]  Starting emulator: %EMULATOR_NAME%
start /b "" "%DEVECO_EMULATOR%" -hvd "%EMULATOR_NAME%" >"%LOG_FILE%" 2>&1
for /L %%I in (1,1,25) do (
  timeout /t 2 /nobreak >nul
  for /f "usebackq delims=" %%T in (`"%DEVECO_HDC%" list targets 2^>nul`) do (
    if not "%%T"=="[Empty]" if not "%%T"=="[Fail]" if not "%%T"=="" (
      echo [OK]    HarmonyOS simulator connected
      exit /b 0
    )
  )
)
echo [ENV_003] No HarmonyOS simulator/device connected ^| Check %LOG_FILE%.
exit /b 1
