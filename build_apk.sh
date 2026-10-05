#!/usr/bin/env bash
# ==============================================================================
# Alpha X Gym - Android Release APK Builder (Bash)
# Builds the production release APK with the latest codebase.
# ==============================================================================

set -e

# ANSI Color Codes
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

echo -e "${CYAN}======================================================================${NC}"
echo -e "${CYAN}   ALPHA X GYM - ANDROID RELEASE APK BUILDER (BASH)${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo ""

# Determine directory paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$SCRIPT_DIR"
MOBILE_DIR="$ROOT_DIR/apps/mobile"
OUTPUT_DIR="$ROOT_DIR/build_outputs"
TARGET_APK="$OUTPUT_DIR/AlphaXGym-Release.apk"
ROOT_APK="$ROOT_DIR/AlphaXGym-Release.apk"

# 1. Check prerequisites
echo -e "${YELLOW}[1/5] Checking tools and prerequisites...${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}[ERROR] Flutter could not be found in PATH.${NC}"
    echo "Please install Flutter: https://docs.flutter.dev/get-started/install"
    exit 1
fi
echo -e "${GREEN} ✔ Flutter detected: $(flutter --version | head -n 1)${NC}"

# 2. Sync with GitHub
echo ""
echo -e "${YELLOW}[2/5] Syncing latest commits from GitHub (origin/main)...${NC}"
if command -v git &> /dev/null; then
    (cd "$ROOT_DIR" && git pull origin main || echo -e "${GRAY} ⚠ git pull encountered an issue. Continuing with current files...${NC}")
    echo -e "${GREEN} ✔ Source code ready.${NC}"
else
    echo -e "${GRAY} ⚠ Git not found, skipping pull.${NC}"
fi

# 3. Enter mobile app directory
echo ""
echo -e "${YELLOW}[3/5] Resolving dependencies in apps/mobile...${NC}"
cd "$MOBILE_DIR"

if [[ "$1" == "--clean" ]]; then
    echo -e "${YELLOW} 🔄 Cleaning build cache (flutter clean)...${NC}"
    flutter clean
fi

flutter pub get
echo -e "${GREEN} ✔ Dependencies up to date.${NC}"

# 4. Build APK
echo ""
echo -e "${YELLOW}[4/5] Compiling Android Release APK (flutter build apk --release)...${NC}"
echo -e "${GRAY}       This typically takes 2-4 minutes depending on your hardware...${NC}"

BUILD_ARGS="--release"
if [[ "$*" == *"--split-per-abi"* ]]; then
    BUILD_ARGS="--release --split-per-abi"
fi

flutter build apk $BUILD_ARGS
echo -e "${GREEN} ✔ Compilation complete!${NC}"

# 5. Copy & Package
echo ""
echo -e "${YELLOW}[5/5] Packaging binary to build_outputs...${NC}"
mkdir -p "$OUTPUT_DIR"

SOURCE_APK="$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$SOURCE_APK" ]; then
    # Fallback search for any generated release APK
    SOURCE_APK=$(find "$MOBILE_DIR/build/app/outputs/flutter-apk" -name "*release*.apk" 2>/dev/null | head -n 1)
fi

if [ -f "$SOURCE_APK" ]; then
    cp -f "$SOURCE_APK" "$TARGET_APK"
    cp -f "$SOURCE_APK" "$ROOT_APK"

    FILE_SIZE_BYTES=$(wc -c < "$TARGET_APK" | tr -d ' ')
    FILE_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $FILE_SIZE_BYTES/1048576}")

    echo ""
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN} 🎉 SUCCESS! Android Release APK Generated Successfully!${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "  File Name:    AlphaXGym-Release.apk"
    echo -e "  File Size:    ${FILE_SIZE_MB} MB (${FILE_SIZE_BYTES} bytes)"
    echo -e "  Location 1:   ${CYAN}${TARGET_APK}${NC}"
    echo -e "  Location 2:   ${CYAN}${ROOT_APK}${NC}"
    echo -e "  Timestamp:    $(date)"
    echo ""
    echo -e "${YELLOW}  📱 Installation instructions:${NC}"
    echo -e "  1. Transfer AlphaXGym-Release.apk to your Android device."
    echo -e "  2. Tap the APK file and select 'Install'."
    echo -e "  3. Allow 'Install from unknown sources' if prompted."
    echo -e "${GREEN}======================================================================${NC}"
else
    echo -e "${RED}[ERROR] Expected APK file not found at: $SOURCE_APK${NC}"
    exit 1
fi
