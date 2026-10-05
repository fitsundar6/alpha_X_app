@echo off
setlocal enabledelayedexpansion

title Alpha X Gym - Android Release APK Builder

echo ======================================================================
echo    ALPHA X GYM - ANDROID RELEASE APK BUILDER
echo ======================================================================
echo.

:: Detect root directory (folder where this script resides)
set "ROOT_DIR=%~dp0"
set "MOBILE_DIR=%ROOT_DIR%apps\mobile"
set "OUTPUT_DIR=%ROOT_DIR%build_outputs"
set "TARGET_APK=%OUTPUT_DIR%\AlphaXGym-Release.apk"
set "ROOT_APK=%ROOT_DIR%AlphaXGym-Release.apk"

:: Check for Flutter installation
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter is not found in your system PATH!
    echo Please install Flutter or add Flutter bin folder to your PATH.
    echo Website: https://docs.flutter.dev/get-started/install
    echo.
    pause
    exit /b 1
)

:: Check for Git installation
where git >nul 2>nul
if %errorlevel% equ 0 (
    echo [1/5] Fetching latest code from GitHub repository...
    cd /d "%ROOT_DIR%"
    git pull origin main
    if %errorlevel% neq 0 (
        echo [WARN] git pull encountered an issue (offline or local changes).
        echo Continuing with current local codebase...
    ) else (
        echo [OK] Codebase is up to date with origin/main.
    )
) else (
    echo [1/5] Git not found in PATH, skipping git pull. Using current files.
)

echo.
echo [2/5] Navigating to mobile application directory:
echo       %MOBILE_DIR%
cd /d "%MOBILE_DIR%"
if %errorlevel% neq 0 (
    echo [ERROR] Could not find apps\mobile directory at:
    echo %MOBILE_DIR%
    pause
    exit /b 1
)

echo.
echo [3/5] Fetching Flutter dependencies (flutter pub get)...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] Failed to fetch Flutter packages!
    pause
    exit /b 1
)

echo.
echo [4/5] Compiling production Android Release APK...
echo       This may take 2-4 minutes depending on your CPU...
echo.

:: Check if user passed arguments (e.g. --split-per-abi or --clean)
set "BUILD_ARGS=--release"
for %%a in (%*) do (
    if "%%a"=="--clean" (
        echo [INFO] Running flutter clean first...
        call flutter clean
        call flutter pub get
    )
    if "%%a"=="--split-per-abi" (
        set "BUILD_ARGS=--release --split-per-abi"
    )
)

call flutter build apk %BUILD_ARGS%
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Flutter build apk failed!
    pause
    exit /b 1
)

echo.
echo [5/5] Packaging and deploying APK to output directory...
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

set "GENERATED_APK=%MOBILE_DIR%\build\app\outputs\flutter-apk\app-release.apk"

if not exist "%GENERATED_APK%" (
    echo [WARN] %GENERATED_APK% not found, checking subdirectories...
    for /r "%MOBILE_DIR%\build\app\outputs\flutter-apk" %%f in (*release*.apk) do (
        set "GENERATED_APK=%%f"
    )
)

if exist "%GENERATED_APK%" (
    copy /y "%GENERATED_APK%" "%TARGET_APK%" >nul
    copy /y "%GENERATED_APK%" "%ROOT_APK%" >nul
    
    echo.
    echo ======================================================================
    echo  SUCCESS! Android Release APK Generated Successfully!
    echo ======================================================================
    echo.
    echo  Primary Location:
    echo    %TARGET_APK%
    echo.
    echo  Root Mirror Location:
    echo    %ROOT_APK%
    echo.
    
    :: Print file size in MB
    for %%I in ("%TARGET_APK%") do (
        set /a "SIZE_MB=%%~zI / 1048576"
        echo  APK Size: ~!SIZE_MB! MB (%%~zI bytes)
        echo  Build Date: %DATE% %TIME%
    )
    echo.
    echo  How to install on Android:
    echo  1. Connect your Android phone via USB or upload to Google Drive/Telegram.
    echo  2. Copy AlphaXGym-Release.apk to your phone.
    echo  3. Tap the file on your phone and choose "Install".
    echo     (Enable "Install from unknown sources" if prompted).
    echo ======================================================================
) else (
    echo [ERROR] Build completed but generated APK could not be located!
)

echo.
pause
