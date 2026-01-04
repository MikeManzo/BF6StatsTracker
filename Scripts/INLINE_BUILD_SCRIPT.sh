#!/bin/bash
# COPY THIS ENTIRE SCRIPT INTO XCODE BUILD PHASE
# Auto-increment build number script for Xcode
# This script increments CFBundleVersion in Info.plist as a 5-digit hexadecimal number
# Uses sed instead of PlistBuddy to avoid sandbox issues

# Only increment for actual builds, not for indexing or analysis
if [ "$ACTION" != "build" ]; then
    exit 0
fi

# Only increment for Release builds (optional - comment out these 3 lines to increment on all builds)
# if [ "$CONFIGURATION" != "Release" ]; then
#     exit 0
# fi

# Find Info.plist - try multiple locations
if [ -n "$INFOPLIST_FILE" ] && [ -f "${PROJECT_DIR}/${INFOPLIST_FILE}" ]; then
    SOURCE_PLIST="${PROJECT_DIR}/${INFOPLIST_FILE}"
elif [ -f "${PROJECT_DIR}/${TARGET_NAME}/Info.plist" ]; then
    SOURCE_PLIST="${PROJECT_DIR}/${TARGET_NAME}/Info.plist"
elif [ -f "${PROJECT_DIR}/BF6StatsTracker/Info.plist" ]; then
    SOURCE_PLIST="${PROJECT_DIR}/BF6StatsTracker/Info.plist"
else
    echo "❌ Error: Could not find Info.plist"
    exit 1
fi

echo "📝 Using Info.plist at: $SOURCE_PLIST"

# Get current build number using grep and sed
BUILD_NUMBER=$(grep -A 1 "CFBundleVersion" "$SOURCE_PLIST" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | tr -d '[:space:]')

if [ -z "$BUILD_NUMBER" ]; then
    echo "⚠️  No build number found, setting to 00001"
    BUILD_NUMBER="00000"
fi

# Convert hex to decimal, increment, convert back to hex
if [[ "$BUILD_NUMBER" =~ ^[0-9A-Fa-f]+$ ]]; then
    # Valid hex number
    DECIMAL_BUILD=$((16#$BUILD_NUMBER))
else
    # Not a valid hex, start at 0
    echo "⚠️  Invalid hex number '$BUILD_NUMBER', starting from 0"
    DECIMAL_BUILD=0
fi

# Increment
NEW_DECIMAL_BUILD=$((DECIMAL_BUILD + 1))

# Convert to 5-digit uppercase hex (pad with zeros)
NEW_BUILD_NUMBER=$(printf "%05X" $NEW_DECIMAL_BUILD)

# Update the build number using sed (in-place edit)
sed -i '' "/<key>CFBundleVersion<\/key>/,/<string>/ s/<string>.*<\/string>/<string>$NEW_BUILD_NUMBER<\/string>/" "$SOURCE_PLIST"

if [ $? -eq 0 ]; then
    echo "✅ Build number incremented: $BUILD_NUMBER → $NEW_BUILD_NUMBER"
else
    echo "❌ Error: Failed to update build number"
    exit 1
fi
