# HarmonyOS Environment Setup Script for Windows (PowerShell)
# Run this script to configure all necessary environment variables
# Usage: Run in PowerShell (no admin required for user variables)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " HarmonyOS Development Environment Setup (PowerShell)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Define DevEco Studio path
$devecoPath = "D:\Program Files\Huawei\DevEco Studio"

# Check if DevEco Studio exists
if (-not (Test-Path $devecoPath)) {
    Write-Host "[ERROR] DevEco Studio not found at: $devecoPath" -ForegroundColor Red
    Write-Host "Please update the `$devecoPath variable in this script." -ForegroundColor Yellow
    exit 1
}

Write-Host "[INFO] DevEco Studio found at: $devecoPath" -ForegroundColor Cyan
Write-Host ""

# Define tool paths
$hdcPath = "$devecoPath\sdk\default\openharmony\toolchains"
$hvigorPath = "$devecoPath\tools\hvigor\bin"
$nodePath = "$devecoPath\tools\node"
$javaPath = "$devecoPath\jbr\bin"

# SDK paths (use D:\HarmonyOS\Sdk to avoid Chinese path encoding issues)
$sdkHome = "D:\HarmonyOS\Sdk"
$ohosSdkHome = "$sdkHome\HarmonyOS-6.0.2\openharmony"

# Check if SDK junction exists, create if not
if (-not (Test-Path "$sdkHome\HarmonyOS-6.0.2")) {
    Write-Host "[INFO] Creating SDK junction link..." -ForegroundColor Cyan
    New-Item -ItemType Junction -Path "$sdkHome\HarmonyOS-6.0.2" -Target "$devecoPath\sdk\default" -Force | Out-Null
    Write-Host "[OK] SDK junction created" -ForegroundColor Green
}

# Check if tools exist
Write-Host "[INFO] Checking tool paths..." -ForegroundColor Cyan

$toolsOk = $true
if (Test-Path "$hdcPath\hdc.exe") {
    Write-Host "[OK] hdc.exe found: $hdcPath" -ForegroundColor Green
} else {
    Write-Host "[ERROR] hdc.exe not found" -ForegroundColor Red
    $toolsOk = $false
}

if (Test-Path "$hvigorPath\hvigorw.bat") {
    Write-Host "[OK] hvigorw.bat found: $hvigorPath" -ForegroundColor Green
} else {
    Write-Host "[ERROR] hvigorw.bat not found" -ForegroundColor Red
    $toolsOk = $false
}

if (Test-Path "$nodePath\node.exe") {
    Write-Host "[OK] node.exe found: $nodePath" -ForegroundColor Green
} else {
    Write-Host "[ERROR] node.exe not found" -ForegroundColor Red
    $toolsOk = $false
}

if (-not $toolsOk) {
    Write-Host ""
    Write-Host "[ERROR] Some tools are missing. Please ensure DevEco Studio is fully installed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Setting Environment Variables" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Set DEVECO_STUDIO_PATH
Write-Host "[INFO] Setting DEVECO_STUDIO_PATH..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("DEVECO_STUDIO_PATH", $devecoPath, "User")
Write-Host "[OK] DEVECO_STUDIO_PATH set to: $devecoPath" -ForegroundColor Green

# Set NODE_HOME
Write-Host "[INFO] Setting NODE_HOME..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("NODE_HOME", $nodePath, "User")
Write-Host "[OK] NODE_HOME set to: $nodePath" -ForegroundColor Green

# Set JAVA_HOME
Write-Host "[INFO] Setting JAVA_HOME..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("JAVA_HOME", "$devecoPath\jbr", "User")
Write-Host "[OK] JAVA_HOME set to: $devecoPath\jbr" -ForegroundColor Green

# Set DEVECO_SDK_HOME
Write-Host "[INFO] Setting DEVECO_SDK_HOME..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("DEVECO_SDK_HOME", $sdkHome, "User")
Write-Host "[OK] DEVECO_SDK_HOME set to: $sdkHome" -ForegroundColor Green

# Set OHOS_BASE_SDK_HOME
Write-Host "[INFO] Setting OHOS_BASE_SDK_HOME..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("OHOS_BASE_SDK_HOME", $ohosSdkHome, "User")
Write-Host "[OK] OHOS_BASE_SDK_HOME set to: $ohosSdkHome" -ForegroundColor Green

# Update PATH
Write-Host ""
Write-Host "[INFO] Updating PATH..." -ForegroundColor Cyan

$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathsToAdd = @($hdcPath, $hvigorPath, $nodePath, $javaPath)
$newPaths = @()

foreach ($path in $pathsToAdd) {
    if ($currentPath -notlike "*$path*") {
        $newPaths += $path
        Write-Host "[INFO] Adding to PATH: $path" -ForegroundColor Cyan
    } else {
        Write-Host "[SKIP] Already in PATH: $path" -ForegroundColor Yellow
    }
}

if ($newPaths.Count -gt 0) {
    $updatedPath = $currentPath + ";" + ($newPaths -join ";")
    [Environment]::SetEnvironmentVariable("Path", $updatedPath, "User")
    Write-Host "[OK] PATH updated successfully" -ForegroundColor Green
} else {
    Write-Host "[OK] All paths already configured" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Environment Variables Set" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The following environment variables have been set:" -ForegroundColor Cyan
Write-Host "  DEVECO_STUDIO_PATH = $devecoPath" -ForegroundColor White
Write-Host "  NODE_HOME          = $nodePath" -ForegroundColor White
Write-Host "  JAVA_HOME          = $devecoPath\jbr" -ForegroundColor White
Write-Host "  DEVECO_SDK_HOME    = $sdkHome" -ForegroundColor White
Write-Host "  OHOS_BASE_SDK_HOME = $ohosSdkHome" -ForegroundColor White
Write-Host ""
Write-Host "PATH includes:" -ForegroundColor Cyan
Write-Host "  $hdcPath (hdc)" -ForegroundColor White
Write-Host "  $hvigorPath (hvigorw)" -ForegroundColor White
Write-Host "  $nodePath (node)" -ForegroundColor White
Write-Host "  $javaPath (java)" -ForegroundColor White
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Emulator Setup Required" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You need to create a HarmonyOS emulator in DevEco Studio:" -ForegroundColor Yellow
Write-Host "  1. Open DevEco Studio" -ForegroundColor White
Write-Host "  2. Go to Tools > Device Manager" -ForegroundColor White
Write-Host "  3. Click 'New Emulator'" -ForegroundColor White
Write-Host "  4. Select 'Phone' type" -ForegroundColor White
Write-Host "  5. Choose HarmonyOS 6.0.2(22) system image" -ForegroundColor White
Write-Host "  6. Complete the creation wizard" -ForegroundColor White
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Verification" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Open a NEW PowerShell/terminal window and run:" -ForegroundColor Cyan
Write-Host "  hdc list targets        - should show connected device/emulator" -ForegroundColor White
Write-Host "  hvigorw --version       - should show hvigor version" -ForegroundColor White
Write-Host "  node --version          - should show node version" -ForegroundColor White
Write-Host ""
Write-Host "To start development:" -ForegroundColor Cyan
Write-Host "  cd app-center" -ForegroundColor White
Write-Host "  .\dev-start.bat" -ForegroundColor White
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Setup Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "NOTE: You must open a NEW terminal window for changes to take effect." -ForegroundColor Yellow