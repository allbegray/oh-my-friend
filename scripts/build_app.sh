#!/usr/bin/env bash
set -e

# 풀 Xcode가 있으면 그 툴체인 사용 (CLT에는 SwiftUIMacros 플러그인이 없어 갤러리 빌드 불가)
if [ -z "$DEVELOPER_DIR" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

echo "🔨 Building OhMyFriend..."

mkdir -p .build/release
APP_NAME="OhMyFriend"
APP_BUNDLE="${APP_NAME}.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"

# Try swift build first, fallback to direct swiftc compilation if CommandLineTools SPM manifest fails
if ! swift build -c release; then
    echo ""
    echo "⚠️ 'swift build' encountered an environment/CommandLineTools manifest link issue."
    echo "🔄 Switching to fallback: Compiling directly with swiftc..."
    ARCH="$(uname -m)"
    mkdir -p .build/module-cache
    PLUGIN_FLAG=""
    SDK_FLAG=""
    XCODE_PLUGINS="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins"
    XCODE_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    if [ -d "$XCODE_PLUGINS" ]; then
        PLUGIN_FLAG="-plugin-path $XCODE_PLUGINS"
    fi
    if [ -d "$XCODE_SDK" ]; then
        SDK_FLAG="-sdk $XCODE_SDK"
    fi
    swiftc -module-cache-path .build/module-cache $PLUGIN_FLAG $SDK_FLAG -O -target "${ARCH}-apple-macosx13.0" Sources/OhMyFriend/*.swift \
        -o ".build/release/${APP_NAME}" \
        -framework AppKit -framework SceneKit -framework SwiftUI -framework CoreGraphics
    echo "✅ Direct compilation succeeded!"
fi

echo "📦 Packaging into ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp ".build/release/${APP_NAME}" "${MACOS_DIR}/"

cat << 'EOF' > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OhMyFriend</string>
    <key>CFBundleIdentifier</key>
    <string>com.hong.ohmyfriend</string>
    <key>CFBundleName</key>
    <string>OhMyFriend</string>
    <key>CFBundleDisplayName</key>
    <string>Oh My Friend</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ App bundle created: ${APP_BUNDLE}"
echo "🚀 You can launch it using: open ${APP_BUNDLE} or ./scripts/run.sh"
