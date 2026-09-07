# ==============================================================================
# FExpense Windows Installer Build Script
# 1. Compiles Flutter release binaries for Windows
# 2. Runs Inno Setup compiler (ISCC) to package FExpense_Setup.exe
# ==============================================================================

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Building FExpense Windows Release & Installer  " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# 1. Build Flutter Windows Release
Write-Host "`n[1/2] Compiling Flutter Windows release build..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Flutter build failed. Aborting installer generation." -ForegroundColor Red
    exit $LASTEXITCODE
}

# 2. Locate Inno Setup Compiler (ISCC.exe)
Write-Host "`n[2/2] Locating Inno Setup Compiler..." -ForegroundColor Yellow
$isccPaths = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)

$iscc = $null
foreach ($path in $isccPaths) {
    if (Test-Path $path) {
        $iscc = $path
        break
    }
}

if (-not $iscc) {
    $cmd = Get-Command iscc -ErrorAction SilentlyContinue
    if ($cmd) {
        $iscc = $cmd.Source
    }
}

if (-not $iscc) {
    Write-Host "[ERROR] Inno Setup compiler (ISCC.exe) was not found." -ForegroundColor Red
    Write-Host "Please ensure Inno Setup 6 is installed." -ForegroundColor Red
    exit 1
}

Write-Host "Found Inno Setup compiler: $iscc" -ForegroundColor Green

# 3. Compile Installer
$scriptPath = Join-Path $PSScriptRoot "windows\installer\fexpense_setup.iss"
Write-Host "Compiling installer script: $scriptPath" -ForegroundColor Yellow

& "$iscc" "$scriptPath"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Inno Setup compilation failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

$outputExe = Join-Path $PSScriptRoot "build\installer\FExpense_Setup.exe"
if (Test-Path $outputExe) {
    $sizeMB = [math]::Round((Get-Item $outputExe).Length / 1MB, 2)
    Write-Host "`n=================================================" -ForegroundColor Green
    Write-Host "  INSTALLER CREATED SUCCESSFULLY!                " -ForegroundColor Green
    Write-Host "  File: $outputExe" -ForegroundColor White
    Write-Host "  Size: $sizeMB MB" -ForegroundColor White
    Write-Host "=================================================" -ForegroundColor Green
}
