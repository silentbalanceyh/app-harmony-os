@echo off
setlocal EnableDelayedExpansion

set "ROOT_DIR=%~dp0.."
pushd "%ROOT_DIR%" >nul
set "ROOT_DIR=%CD%"
popd >nul

set "APP_NAME="
set "APP_LABEL="
set "TEMPLATE_DIR=%ROOT_DIR%\templates\app-template"
set "RUN_BUILD=false"

:parse
if "%~1"=="" goto validate
if "%~1"=="--name" (
    set "APP_NAME=%~2"
    shift
    shift
    goto parse
)
if "%~1"=="--label" (
    set "APP_LABEL=%~2"
    shift
    shift
    goto parse
)
if "%~1"=="--template" (
    set "TEMPLATE_DIR=%~2"
    shift
    shift
    goto parse
)
if "%~1"=="--build" (
    set "RUN_BUILD=true"
    shift
    goto parse
)
if "%~1"=="--help" goto usage
if "%~1"=="-h" goto usage
echo [ERROR] Unknown argument: %~1
exit /b 1

:usage
echo Usage: scripts\create-app.bat --name app-example --label "示例应用" [--template templates\app-template] [--build]
exit /b 0

:validate
if not defined APP_NAME (
    echo [ERROR] --name is required
    exit /b 1
)
if not defined APP_LABEL (
    echo [ERROR] --label is required
    exit /b 1
)
echo %APP_NAME%| findstr /R "^app-[a-z0-9][a-z0-9-]*$" >nul
if errorlevel 1 (
    echo [ERROR] --name must match app-[a-z0-9][a-z0-9-]*
    exit /b 1
)
echo %APP_NAME%| findstr "--" >nul
if not errorlevel 1 (
    echo [ERROR] --name cannot contain consecutive hyphens
    exit /b 1
)
if "%APP_NAME:~-1%"=="-" (
    echo [ERROR] --name cannot end with a hyphen
    exit /b 1
)
if not exist "%TEMPLATE_DIR%\app.json" (
    echo [ERROR] Template app.json not found: %TEMPLATE_DIR%
    exit /b 1
)
if exist "%ROOT_DIR%\%APP_NAME%" (
    echo [ERROR] Target app already exists: %ROOT_DIR%\%APP_NAME%
    exit /b 1
)

set "SUFFIX=%APP_NAME:app-=%"
set "BUNDLE_SUFFIX=%SUFFIX:-=%"
set "APP_BUNDLE=com.zerows.app%BUNDLE_SUFFIX%"
set "MEDIA_NAME=ic_%APP_NAME:-=_%"
set "TARGET_ROOT=%ROOT_DIR%\%APP_NAME%"

echo [INFO] Creating %APP_NAME% from %TEMPLATE_DIR%
xcopy "%TEMPLATE_DIR%" "%TARGET_ROOT%\" /E /I /Q >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy template
    exit /b 1
)

rmdir /S /Q "%TARGET_ROOT%\.deveco-sdk-shim" 2>nul
rmdir /S /Q "%TARGET_ROOT%\.hvigor" 2>nul
rmdir /S /Q "%TARGET_ROOT%\build" 2>nul
rmdir /S /Q "%TARGET_ROOT%\entry\build" 2>nul
rmdir /S /Q "%TARGET_ROOT%\entry\.preview" 2>nul

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root='%TARGET_ROOT%'; $app='%APP_NAME%'; $bundle='%APP_BUNDLE%'; $label='%APP_LABEL%'; Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -notin '.png','.jpg','.jpeg','.webp','.wav','.hap','.app' } | ForEach-Object { $text=[IO.File]::ReadAllText($_.FullName); $text=$text.Replace('_APP_NAME_',$app).Replace('_BUNDLE_NAME_',$bundle).Replace('_LABEL_',$label); [IO.File]::WriteAllText($_.FullName,$text,[Text.UTF8Encoding]::new($false)) }"
if errorlevel 1 (
    echo [ERROR] Placeholder replacement failed
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$path='%ROOT_DIR%\app-center\app.json'; $app='%APP_NAME%'; $json=Get-Content -Raw -LiteralPath $path | ConvertFrom-Json; foreach($key in 'dependsOn','launchTargets'){ if($null -eq $json.$key){ $json | Add-Member -NotePropertyName $key -NotePropertyValue @() }; if(@($json.$key) -notcontains $app){ $json.$key = @($json.$key) + $app } }; $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path -Encoding UTF8"
if errorlevel 1 (
    echo [ERROR] Failed to update app-center app.json
    exit /b 1
)

if not exist "%ROOT_DIR%\app-center\entry\src\main\resources\base\media" mkdir "%ROOT_DIR%\app-center\entry\src\main\resources\base\media"
set "ICON_FILE=%ROOT_DIR%\app-center\entry\src\main\resources\base\media\%MEDIA_NAME%.svg"
if not exist "%ICON_FILE%" (
    >"%ICON_FILE%" echo ^<svg width="128" height="128" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg"^>
    >>"%ICON_FILE%" echo   ^<rect x="12" y="12" width="40" height="40" rx="10" fill="#F8FAFC" stroke="#64748B" stroke-width="3"/^>
    >>"%ICON_FILE%" echo   ^<path d="M22 32H42" stroke="#64748B" stroke-width="3" stroke-linecap="round"/^>
    >>"%ICON_FILE%" echo   ^<path d="M32 22V42" stroke="#64748B" stroke-width="3" stroke-linecap="round"/^>
    >>"%ICON_FILE%" echo ^</svg^>
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$path='%ROOT_DIR%\app-center\entry\src\main\ets\pages\Index.ets'; $id='%APP_NAME%'; $label='%APP_LABEL%'; $bundle='%APP_BUNDLE%'; $media='%MEDIA_NAME%'; $text=Get-Content -Raw -LiteralPath $path; if($text.Contains(\"id: '$id'\")){ exit 0 }; $anchor='  ];'; $idx=$text.IndexOf($anchor); if($idx -lt 0){ Write-Error 'Could not find ManagedApp array insertion anchor'; exit 2 }; $prefix=','+[Environment]::NewLine; $entry=@\"`n    {`n      id: '$id',`n      label: '$label',`n      bundleName: '$bundle',`n      moduleName: 'entry',`n      abilityName: 'EntryAbility',`n      icon: `$r('app.media.$media'),`n      iconBgColor: '#F4F7FB',`n      iconStrokeColor: '#64748B',`n      installed: true,`n      stylePreset: 0`n    }`n\"@; $text=$text.Insert($idx,$prefix+$entry); Set-Content -LiteralPath $path -Value $text -Encoding UTF8"
if errorlevel 2 (
    echo [WARN] Skipped app-center Index.ets registration; add the ManagedApp entry manually.
) else if errorlevel 1 (
    echo [ERROR] Failed to update app-center Index.ets
    exit /b 1
)

if exist "%ROOT_DIR%\setup-deveco-config.bat" (
    call "%ROOT_DIR%\setup-deveco-config.bat"
) else (
    echo [WARN] DevEco setup hook unavailable on Windows; skipping SDK shim/run configuration setup.
)

if "%RUN_BUILD%"=="true" (
    pushd "%TARGET_ROOT%"
    call dev-build.bat
    popd
    pushd "%ROOT_DIR%\app-center"
    call dev-build.bat
    popd
) else (
    echo [INFO] Build verification skipped. Pass --build to attempt builds.
)

echo [OK] Created %APP_NAME%
echo   Path: %TARGET_ROOT%
echo   Bundle: %APP_BUNDLE%
echo   Label: %APP_LABEL%
echo   Registered in app-center: app.json and Index.ets
exit /b 0
