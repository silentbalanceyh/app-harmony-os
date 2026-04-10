@echo off
rem HarmonyOS Environment Setup Script for Windows
rem Run this script to configure all necessary environment variables

echo ============================================================
echo  HarmonyOS Development Environment Setup
echo ============================================================
echo.

rem Define DevEco Studio path
set "DEVECO_PATH=D:\Program Files\Huawei\DevEco Studio"

rem Check if DevEco Studio exists
if not exist "%DEVECO_PATH%" (
    echo [ERROR] DevEco Studio not found at: %DEVECO_PATH%
    echo Please update the DEVECO_PATH variable in this script.
    pause
    exit /b 1
)

echo [INFO] DevEco Studio found at: %DEVECO_PATH%
echo.

rem Set DEVECO_STUDIO_PATH (user environment variable)
echo [INFO] Setting DEVECO_STUDIO_PATH...
setx DEVECO_STUDIO_PATH "%DEVECO_PATH%" >nul 2>nul
if errorlevel 1 (
    echo [WARN] Could not set DEVECO_STUDIO_PATH via setx
    echo Please set manually in System Environment Variables
) else (
    echo [OK] DEVECO_STUDIO_PATH set to: %DEVECO_PATH%
)

rem Set NODE_HOME (for hvigor)
echo [INFO] Setting NODE_HOME...
setx NODE_HOME "%DEVECO_PATH%\tools\node" >nul 2>nul
if errorlevel 1 (
    echo [WARN] Could not set NODE_HOME via setx
) else (
    echo [OK] NODE_HOME set to: %DEVECO_PATH%\tools\node
)

rem Define paths to add to PATH
set "HDC_PATH=%DEVECO_PATH%\sdk\default\openharmony\toolchains"
set "HVIGOR_PATH=%DEVECO_PATH%\tools\hvigor\bin"
set "NODE_PATH=%DEVECO_PATH%\tools\node"

rem Check if paths exist
echo [INFO] Checking tool paths...
if exist "%HDC_PATH%\hdc.exe" (
    echo [OK] hdc.exe found: %HDC_PATH%
) else (
    echo [ERROR] hdc.exe not found
)
if exist "%HVIGOR_PATH%\hvigorw.bat" (
    echo [OK] hvigorw.bat found: %HVIGOR_PATH%
) else (
    echo [ERROR] hvigorw.bat not found
)
if exist "%NODE_PATH%\node.exe" (
    echo [OK] node.exe found: %NODE_PATH%
) else (
    echo [ERROR] node.exe not found
)

echo.
echo ============================================================
echo  PATH Configuration
echo ============================================================
echo.
echo The following paths need to be added to your user PATH:
echo   1. %HDC_PATH%
echo   2. %HVIGOR_PATH%
echo   3. %NODE_PATH%
echo.
echo You can add them manually:
echo   1. Press Win+R, type sysdm.cpl, press Enter
echo   2. Click "Advanced" tab, then "Environment Variables"
echo   3. Find "Path" in User variables, click "Edit"
echo   4. Add the three paths above
echo.
echo OR run the following PowerShell command (as Administrator):
echo.
echo   $paths = @(
echo     'D:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains',
echo     'D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin',
echo     'D:\Program Files\Huawei\DevEco Studio\tools\node'
echo   )
echo   $currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
echo   $newPath = ($paths | Where-Object { $currentPath -notlike "*$_*" }) -join ';'
echo   if ($newPath) { [Environment]::SetEnvironmentVariable('Path', "$currentPath;$newPath", 'User') }
echo.
echo ============================================================
echo  Emulator Setup Required
echo ============================================================
echo.
echo You need to create a HarmonyOS emulator in DevEco Studio:
echo   1. Open DevEco Studio
echo   2. Go to Tools ^> Device Manager
echo   3. Click "New Emulator"
echo   4. Select "Phone" type
echo   5. Choose HarmonyOS 6.0.2(22) system image
echo   6. Complete the creation wizard
echo.
echo ============================================================
echo  Verification
echo ============================================================
echo.
echo After configuration, open a NEW terminal and run:
echo   hdc list targets        - should show connected device/emulator
echo   hvigorw --version       - should show hvigor version
echo   node --version          - should show node version
echo.
echo To start development:
echo   cd app-center
echo   dev-start.bat
echo.
pause