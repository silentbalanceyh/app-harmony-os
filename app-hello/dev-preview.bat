@echo off
REM dev-preview.bat — Open DevEco Studio Previewer for current app
REM Usage: dev-preview.bat [page_name]

setlocal enabledelayedexpansion

set "APP_ROOT=%~dp0"
set "APP_ROOT=%APP_ROOT:~0,-1%"
for %%I in ("%APP_ROOT%") do set "APP_NAME=%%~nxI"

if defined DEVECO_STUDIO_PATH (
    set "DEVECO=%DEVECO_STUDIO_PATH%"
) else (
    set "DEVECO=C:\Program Files\Huawei\DevEco Studio"
)

set "PAGES_JSON=%APP_ROOT%\entry\src\main\resources\base\profile\main_pages.json"
set "ETS_DIR=%APP_ROOT%\entry\src\main\ets"

if "%~1"=="" (
    for /f "usebackq delims=" %%p in (`python3 -c "import json; f=open(r'%PAGES_JSON%','r',encoding='utf-8'); d=json.load(f); print(d['src'][0].split('/')[-1] if d.get('src') else 'Index')"`) do set "PAGE_NAME=%%p"
) else (
    set "PAGE_NAME=%~1"
)

set "PAGE_FILE=%ETS_DIR%\pages\%PAGE_NAME%.ets"

if not exist "%PAGE_FILE%" (
    echo Page not found: %PAGE_NAME%
    echo Available pages:
    python3 -c "import json; f=open(r'%PAGES_JSON%','r',encoding='utf-8'); d=json.load(f); [print(f'  {p}') for p in d.get('src',[])]"
    exit /b 1
)

echo Opening DevEco Studio for %APP_NAME% — Preview: %PAGE_NAME%
echo File: %PAGE_FILE%
echo.
echo Steps in DevEco Studio:
echo   1. Open the file shown above
echo   2. Click Previewer tab on the right panel
echo   3. Edit code — preview auto-refreshes

start "" "%DEVECO%\bin\devecostudio64.exe" "%PAGE_FILE%"
