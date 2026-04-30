@echo off
setlocal EnableDelayedExpansion

if "%~1"==":read_string" goto read_string
if "%~1"==":read_array" goto read_array
if "%~1"==":list_apps" goto list_apps
exit /b 0

:read_string
python3 -c "import json,sys; d=json.load(open(sys.argv[1],encoding='utf-8')); v=d.get(sys.argv[2],''); print(v if isinstance(v,str) else '')" "%~2" "%~3"
exit /b %errorlevel%

:read_array
python3 -c "import json,sys; d=json.load(open(sys.argv[1],encoding='utf-8')); [print(x) for x in d.get(sys.argv[2],[]) if isinstance(x,str)]" "%~2" "%~3"
exit /b %errorlevel%

:list_apps
if exist "%WORKSPACE_ROOT%\app-center\app.json" echo app-center
for /d %%A in ("%WORKSPACE_ROOT%\app-*") do (
  if /I not "%%~nxA"=="app-center" if exist "%%A\app.json" echo %%~nxA
)
exit /b 0
