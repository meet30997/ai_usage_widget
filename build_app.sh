#!/bin/bash
set -e

echo "🔨 Building AI Usage Widget in Release mode..."
swift build -c release

APP_NAME="AI Usage Tracker.app"
BUNDLE_DIR="build/$APP_NAME"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MacOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📁 Creating app bundle structure at $BUNDLE_DIR..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MacOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "🚚 Copying compiled binary and brand assets..."
cp ".build/release/AIUsageWidget" "$MacOS_DIR/AIUsageWidget"
cp assets/*.png "$RESOURCES_DIR/" 2>/dev/null || true

echo "📄 Creating Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AIUsageWidget</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>dev.aiusagetracker.app</string>
    <key>CFBundleName</key>
    <string>AI Usage Tracker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.4.2</string>
    <key>CFBundleVersion</key>
    <string>7</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "📄 Creating Entitlements.plist..."
cat << 'EOF' > "Entitlements.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
EOF

chmod +x "$MacOS_DIR/AIUsageWidget"

echo "🔏 Code-signing app bundle with entitlements..."
xattr -cr "$BUNDLE_DIR"
codesign --force --deep --options runtime --entitlements Entitlements.plist --sign - "$BUNDLE_DIR"

echo "✅ App bundle created and signed successfully at build/$APP_NAME"
echo "🚀 To run the app, execute: open 'build/$APP_NAME'"
