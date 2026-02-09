#!/bin/bash
# Script to perform a clean build and run the app with diagnostic output
# Usage: ./scripts/clean_build_and_test.sh

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

echo "========================================="
echo "Clean Build and Test Script"
echo "========================================="
echo ""

# Step 1: Clean build folder
echo "[1/5] Cleaning build folder..."
if xcodebuild clean -project Xattr-remove.xcodeproj -scheme Xattr-remove -quiet; then
    echo "✓ Build folder cleaned"
else
    echo "✗ Failed to clean build folder"
    exit 1
fi
echo ""

# Step 2: Clean derived data
echo "[2/5] Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Xattr-remove-*
echo "✓ Derived data cleaned"
echo ""

echo "========================================="
echo "Clean Complete!"
echo "========================================="
echo ""
echo 
