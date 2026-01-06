#!/bin/bash

# Configuration
APP_NAME="TimeOut"
BUILD_DIR=".build/release"
ICON_SOURCE="Sources/TimeOut/Resources/AppIcon.png"
OUTPUT_DIR="."

echo "🚀 Starting packaging for $APP_NAME..."

# 1. Build Swift Project
echo "🛠️  Building release binary..."
swift build -c release
if [ $? -ne 0 ]; then
    echo "❌ Build failed."
    exit 1
fi

BUILD_DIR=$(swift build -c release --show-bin-path)
echo "✅ Build directory: $BUILD_DIR"

# 2. Create App Bundle Structure
echo "📂 Creating App Bundle..."
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy Binary and Resources
echo "📦 Copying binary..."
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Bundle Resources (if exists)
RESOURCE_BUNDLE="$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    echo "📦 Copying resource bundle..."
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
else
    echo "⚠️ Resource bundle not found at $RESOURCE_BUNDLE"
fi

# 4. Create Info.plist
echo "📝 Creating Info.plist..."
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.timeout.clone</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/> <!-- Run as agent (menu bar app) -->
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 5. Copy ICNS Icon
ICNS_SOURCE="Sources/TimeOut/Resources/AppIcon.icns"
if [ -f "$ICNS_SOURCE" ]; then
    echo "📦 Copying AppIcon.icns..."
    cp "$ICNS_SOURCE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "✅ Icon copied."
else
    echo "⚠️  AppIcon.icns not found. Run ./create_rounded_icon.sh first."
fi

echo "🎉 Packaging Complete! App located at: $APP_BUNDLE"
echo "👉 You can move it to /Applications to install."
