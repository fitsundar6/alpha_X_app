<#
.SYNOPSIS
    Builds the Alpha X Gym Production Android Release APK with latest code.

.DESCRIPTION
    Automates the entire process:
    1. Validates Flutter and Git environments.
    2. Pulls the latest commits from the main branch.
    3. Fetches Dart/Flutter dependencies (flutter pub get).
    4. Compiles the Android Release APK (flutter build apk --release).
    5. Copies and mirrors the resulting APK to build_outputs/ and project root.
    6. Displays file size, SHA256 checksum, and installation instructions.

.PARAMETER Clean
    Performs `flutter clean` before building.

.PARAMETER NoPull
    Skips `git pull origin main` and uses local working tree as-is.

.PARAMETER SplitAbi
    Builds architecture-specific APKs (arm64-v8a, armeabi-v7a, x86_64) for smaller file sizes.

.PARAMETER OpenFolder
    Opens Windows Explorer directly to the output folder when build finishes.

.EXAMPLE
    .\build_apk.ps1
    .\build_apk.ps1 -Clean
    .\build_apk.ps1 -NoPull -OpenFolder
#>

param(
    [switch]$Clean,
    [switch]$NoPull,
    [switch]$SplitAbi,
    [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

# Define Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = $ScriptDir
$MobileDir = Join-Path $RootDir "apps\mobile"
$OutputDir = Join-Path $RootDir "build_outputs"
$TargetApk = Join-Path $OutputDir "AlphaXGym-Release.apk"
$RootApk = Join-Path $RootDir "AlphaXGym-Release.apk"

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   ALPHA X GYM - ANDROID RELEASE APK BUILDER (POWERSHELL)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check prerequisites
Write-Host "[1/5] Checking build tools and prerequisites..." -ForegroundColor Yellow
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Host "[ERROR] Flutter was not found in your PATH!" -ForegroundColor Red
    Write-Host "Please install Flutter and add it to your system PATH: https://docs.flutter.dev" -ForegroundColor Red
    exit 1
}

$flutterVersion = (flutter --version | Select-Object -First 1)
Write-Host " ✔ Flutter detected: $flutterVersion" -ForegroundColor Green

# 2. Git sync
if (-not $NoPull) {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        Write-Host ""
        Write-Host "[2/5] Syncing latest source code from GitHub (origin/main)..." -ForegroundColor Yellow
        try {
            Push-Location $RootDir
            git pull origin main
            Write-Host " ✔ Codebase synced with origin/main" -ForegroundColor Green
        } catch {
            Write-Host " ⚠ Warning: git pull failed (offline or local changes). Continuing with local files..." -ForegroundColor DarkYellow
        } finally {
            Pop-Location
        }
    } else {
        Write-Host " ⚠ Git not found in PATH, skipping pull." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "[2/5] Skipping git pull (-NoPull flag supplied)." -ForegroundColor Gray
}

# 3. Enter mobile app directory
Write-Host ""
Write-Host "[3/5] Navigating to Flutter mobile project ($MobileDir)..." -ForegroundColor Yellow
if (-not (Test-Path $MobileDir)) {
    Write-Host "[ERROR] Path does not exist: $MobileDir" -ForegroundColor Red
    exit 1
}

Push-Location $MobileDir

try {
    # Clean if requested
    if ($Clean) {
        Write-Host " 🔄 Cleaning stale build artifacts (flutter clean)..." -ForegroundColor Yellow
        flutter clean
    }

    # Dependencies
    Write-Host " 📦 Fetching dependencies (flutter pub get)..." -ForegroundColor Yellow
    flutter pub get
    Write-Host " ✔ Dependencies resolved." -ForegroundColor Green

    # 4. Build Release APK
    Write-Host ""
    Write-Host "[4/5] Compiling Android Release APK (flutter build apk --release)..." -ForegroundColor Yellow
    Write-Host "       This typically takes 2-4 minutes..." -ForegroundColor Gray
    
    $startTime = Get-Date

    if ($SplitAbi) {
        Write-Host "       Using --split-per-abi for architecture-optimized APKs..." -ForegroundColor Gray
        flutter build apk --release --split-per-abi
    } else {
        flutter build apk --release
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "[ERROR] Flutter build apk failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    $elapsed = (Get-Date) - $startTime
    Write-Host " ✔ Compilation succeeded in $($elapsed.Minutes)m $($elapsed.Seconds)s!" -ForegroundColor Green

    # 5. Locate and Copy Output
    Write-Host ""
    Write-Host "[5/5] Deploying output APK binaries..." -ForegroundColor Yellow

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $sourceApk = Join-Path $MobileDir "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $sourceApk)) {
        # Search for any generated release apk in the output directory
        $found = Get-ChildItem -Path (Join-Path $MobileDir "build\app\outputs\flutter-apk") -Filter "*release*.apk" | Select-Object -First 1
        if ($found) {
            $sourceApk = $found.FullName
        }
    }

    if (Test-Path $sourceApk) {
        Copy-Item -Path $sourceApk -Destination $TargetApk -Force
        Copy-Item -Path $sourceApk -Destination $RootApk -Force

        $fileInfo = Get-Item $TargetApk
        $sizeMb = [Math]::Round($fileInfo.Length / 1MB, 2)
        $sha256 = (Get-FileHash -Path $TargetApk -Algorithm SHA256).Hash

        Write-Host ""
        Write-Host "======================================================================" -ForegroundColor Green
        Write-Host " 🎉 SUCCESS! Android Release APK Generated Successfully!" -ForegroundColor Green
        Write-Host "======================================================================" -ForegroundColor Green
        Write-Host "  File Name:    AlphaXGym-Release.apk" -ForegroundColor White
        Write-Host "  File Size:    $sizeMb MB ($($fileInfo.Length) bytes)" -ForegroundColor White
        Write-Host "  Location 1:   $TargetApk" -ForegroundColor Cyan
        Write-Host "  Location 2:   $RootApk" -ForegroundColor Cyan
        Write-Host "  SHA-256:      $sha256" -ForegroundColor Gray
        Write-Host "  Build Time:   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  📱 How to install on your Android phone:" -ForegroundColor Yellow
        Write-Host "  1. Copy AlphaXGym-Release.apk to your phone (via USB, Drive, or Telegram)." -ForegroundColor White
        Write-Host "  2. Open the file on your device and tap 'Install'." -ForegroundColor White
        Write-Host "  3. If prompted, allow 'Install from unknown sources'." -ForegroundColor White
        Write-Host "======================================================================" -ForegroundColor Green

        if ($OpenFolder) {
            Invoke-Item $OutputDir
        }
    } else {
        Write-Host "[ERROR] Could not find compiled APK at: $sourceApk" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}
