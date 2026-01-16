#!/bin/bash
set -e

# Claude Manager Release Script
# Usage: ./scripts/release.sh 1.2.0

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: ./scripts/release.sh <version>"
    echo "Example: ./scripts/release.sh 1.2.0"
    exit 1
fi

echo "Building Claude Manager v$VERSION..."

# Build release
swift build -c release

# Create app bundle directory structure
APP_NAME="ClaudeManager.app"
CONTENTS_DIR="$APP_NAME/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_NAME"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp .build/release/ClaudeManager "$MACOS_DIR/"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeManager</string>
    <key>CFBundleIdentifier</key>
    <string>com.daniellauding.claude-manager</string>
    <key>CFBundleName</key>
    <string>Claude Manager</string>
    <key>CFBundleDisplayName</key>
    <string>Claude Manager</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Created $APP_NAME"

# Create zip for distribution
ZIP_NAME="ClaudeManager-v$VERSION.zip"
rm -f "$ZIP_NAME"
zip -r "$ZIP_NAME" "$APP_NAME"

echo "Created $ZIP_NAME"

# Calculate SHA256 for Homebrew
SHA256=$(shasum -a 256 "$ZIP_NAME" | cut -d' ' -f1)
echo ""
echo "SHA256: $SHA256"
echo ""
echo "Update Homebrew formula with:"
echo "  version \"$VERSION\""
echo "  sha256 \"$SHA256\""
echo ""
echo "To create a GitHub release:"
echo "  1. git tag v$VERSION"
echo "  2. git push origin v$VERSION"
echo "  3. Upload $ZIP_NAME to the release"
