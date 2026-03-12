#!/bin/bash

# Auto-increment build number script for Xcode
# Increments CURRENT_PROJECT_VERSION in the Xcode project file (the authoritative source)
# and keeps Info.plist in sync. Build numbers are 5-digit uppercase hexadecimal (e.g., 00001, 0000A, 000FF).

# Only increment for actual builds, not for indexing or analysis
if [ "$ACTION" != "build" ]; then
    exit 0
fi

# Only increment for Release builds (optional - remove this if you want it for all builds)
# if [ "$CONFIGURATION" != "Release" ]; then
#     exit 0
# fi

# ── Locate project file ────────────────────────────────────────
PROJECT_FILE="${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj/project.pbxproj"
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: Could not find project.pbxproj at $PROJECT_FILE"
    exit 1
fi

# ── Find Info.plist ────────────────────────────────────────────
if [ -n "$INFOPLIST_FILE" ] && [ -f "${PROJECT_DIR}/${INFOPLIST_FILE}" ]; then
    SOURCE_PLIST="${PROJECT_DIR}/${INFOPLIST_FILE}"
elif [ -f "${PROJECT_DIR}/${TARGET_NAME}/Info.plist" ]; then
    SOURCE_PLIST="${PROJECT_DIR}/${TARGET_NAME}/Info.plist"
elif [ -f "${PROJECT_DIR}/BF6StatsTracker/Info.plist" ]; then
    SOURCE_PLIST="${PROJECT_DIR}/BF6StatsTracker/Info.plist"
fi

# ── Get current build number from Info.plist (hex is authoritative) ──
BUILD_HEX=""
if [ -n "$SOURCE_PLIST" ] && [ -f "$SOURCE_PLIST" ]; then
    BUILD_HEX=$(grep -A 1 "CFBundleVersion" "$SOURCE_PLIST" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | tr -d '[:space:]')
fi

if [ -z "$BUILD_HEX" ]; then
    echo "⚠️  No build number found, starting at 00001"
    BUILD_HEX="00000"
fi

# Convert hex to decimal, increment, convert back to 5-digit hex
if [[ "$BUILD_HEX" =~ ^[0-9A-Fa-f]+$ ]]; then
    DECIMAL_BUILD=$((16#$BUILD_HEX))
else
    echo "⚠️  Invalid hex number '$BUILD_HEX', starting from 0"
    DECIMAL_BUILD=0
fi

NEW_DECIMAL=$((DECIMAL_BUILD + 1))
NEW_HEX=$(printf "%05X" $NEW_DECIMAL)

echo "📝 Incrementing build number: $BUILD_HEX → $NEW_HEX (decimal: $DECIMAL_BUILD → $NEW_DECIMAL)"

# ── Update CURRENT_PROJECT_VERSION in project.pbxproj ──────────
# Store as decimal integer in project settings (Xcode expects a number)
CURRENT_PROJECT_VER=$(grep -m 1 "CURRENT_PROJECT_VERSION" "$PROJECT_FILE" | sed 's/[^0-9]//g')
sed -i '' "s/CURRENT_PROJECT_VERSION = ${CURRENT_PROJECT_VER};/CURRENT_PROJECT_VERSION = ${NEW_DECIMAL};/g" "$PROJECT_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Updated CURRENT_PROJECT_VERSION in project: $CURRENT_PROJECT_VER → $NEW_DECIMAL"
else
    echo "❌ Error: Failed to update project build number"
    exit 1
fi

# ── Update Info.plist with hex build number ────────────────────
if [ -n "$SOURCE_PLIST" ] && [ -f "$SOURCE_PLIST" ]; then
    sed -i '' "/<key>CFBundleVersion<\/key>/,/<string>/ s/<string>.*<\/string>/<string>$NEW_HEX<\/string>/" "$SOURCE_PLIST"
    echo "✅ Updated CFBundleVersion in Info.plist: $NEW_HEX"
fi

echo "🎯 Build number is now: $NEW_HEX (hex) / $NEW_DECIMAL (decimal)"
