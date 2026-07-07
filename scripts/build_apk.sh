#!/bin/bash
# Stremini AI — Local APK Build Script
# Run this on your machine to build a working APK.
#
# Prerequisites:
#   - Flutter 3.41+ (https://flutter.dev)
#   - Android SDK (API 36 + build-tools 36.0.0)
#   - Java 17+
#
# Usage:
#   chmod +x scripts/build_apk.sh
#   ./scripts/build_apk.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║          Stremini AI — APK Build Script                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Check prerequisites ──────────────────────────────────────
echo "Checking prerequisites..."
command -v flutter >/dev/null 2>&1 || { echo "ERROR: Flutter not installed. Install from https://flutter.dev"; exit 1; }
command -v java >/dev/null 2>&1 || { echo "ERROR: Java not installed."; exit 1; }

FLUTTER_VER=$(flutter --version 2>&1 | head -1)
echo "  Flutter: $FLUTTER_VER"
echo "  Java:    $(java -version 2>&1 | head -1)"
echo ""

# ── Check local.properties ───────────────────────────────────
if [ ! -f android/local.properties ]; then
    echo "ERROR: android/local.properties not found."
    echo "Copy android/local.properties.example to android/local.properties"
    echo "and fill in your API keys."
    exit 1
fi

# Check that required keys are present
GROQ_KEY=$(grep "^groq.api.key=" android/local.properties | cut -d'=' -f2)
COMPOSIO_KEY=$(grep "^composio.consumer.key=" android/local.properties | cut -d'=' -f2)

if [ -z "$GROQ_KEY" ]; then
    echo "ERROR: groq.api.key missing from android/local.properties"
    exit 1
fi
if [ -z "$COMPOSIO_KEY" ]; then
    echo "ERROR: composio.consumer.key missing from android/local.properties"
    exit 1
fi

echo "Keys found:"
echo "  Groq API key:     ${GROQ_KEY:0:10}...${GROQ_KEY: -4}"
echo "  Composio key:     ${COMPOSIO_KEY:0:10}...${COMPOSIO_KEY: -4}"
echo ""

# ── Build ────────────────────────────────────────────────────
echo "Installing dependencies..."
flutter pub get

echo ""
echo "Building release APK..."
echo "  (this takes 5-15 minutes on first run, 2-3 min on subsequent runs)"
echo ""

flutter build apk --release \
    --dart-define=GROQ_API_KEY="$GROQ_KEY"

# ── Result ───────────────────────────────────────────────────
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  ✅ BUILD SUCCESSFUL                                     ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║  APK: $APK_PATH"
    echo "║  Size: $APK_SIZE"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Install on your phone:"
    echo "  adb install $APK_PATH"
    echo ""
    echo "Or copy the APK to your phone and tap to install."
else
    echo ""
    echo "❌ BUILD FAILED — check the output above for errors."
    exit 1
fi
