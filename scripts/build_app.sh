#!/usr/bin/env bash
set -e

# 풀 Xcode가 있으면 그 툴체인 사용 (CLT에는 SwiftUIMacros 플러그인이 없어 갤러리 빌드 불가)
if [ -z "$DEVELOPER_DIR" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

echo "🔨 Building OhMineFriend..."

mkdir -p .build/release
APP_NAME="OhMineFriend"
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
    swiftc -module-cache-path .build/module-cache $PLUGIN_FLAG $SDK_FLAG -O -target "${ARCH}-apple-macosx13.0" Sources/OhMineFriend/*.swift \
        -o ".build/release/${APP_NAME}" \
        -framework AppKit -framework SceneKit -framework SwiftUI -framework CoreGraphics
    echo "✅ Direct compilation succeeded!"
fi

echo "📦 Packaging into ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp ".build/release/${APP_NAME}" "${MACOS_DIR}/"

VERSION=$(grep -m 1 -oE '\[v[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md 2>/dev/null | tr -d '[v]' || true)
if [ -z "$VERSION" ]; then
    VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.35.0")
fi

cat << EOF > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OhMineFriend</string>
    <key>CFBundleIdentifier</key>
    <string>com.hong.ohminefriend</string>
    <key>CFBundleName</key>
    <string>OhMineFriend</string>
    <key>CFBundleDisplayName</key>
    <string>Oh Mine Friend</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>창을 Dock으로 치우는 기능이 System Events에 창 최소화를 요청할 때 사용합니다.</string>
</dict>
</plist>
EOF

# ---------------------------------------------------------------
# 코드 서명
#
# macOS 13+ arm64 는 서명 없는 실행 파일을 거부하고, Mach-O 링커가 붙이는
# ad-hoc 서명만으로는 번들이 성립하지 않는다(CodeResources 가 없어
# "code has no resources but signature indicates they must be present").
# 그 상태로 배포하면 Gatekeeper 가 앱을 '손상됨'으로 판정하므로,
# 항상 번들 전체를 서명해 _CodeSignature/CodeResources 를 만든다.
#
# SIGNING_IDENTITY 가 있거나 키체인에 Developer ID Application 인증서가 있으면
# 그 인증서 + Hardened Runtime 으로 서명한다(공증 필수 요건).
# 없으면 ad-hoc 으로 서명한다 — 무결성은 확보되지만 공증은 불가능하다.
# ---------------------------------------------------------------
ENTITLEMENTS="${DIR}/scripts/OhMineFriend.entitlements"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"

if [ -z "${SIGNING_IDENTITY}" ]; then
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -m 1 'Developer ID Application' | sed -E 's/^[^"]*"(.*)"$/\1/')" || true
fi

# Hardened Runtime 은 공증의 전제조건이라 두 경로 모두에 적용해,
# 로컬 ad-hoc 빌드가 배포본과 같은 제약(권한 누락 등)을 드러내게 한다.
if [ -n "${SIGNING_IDENTITY}" ]; then
    echo "🔐 Signing with Developer ID: ${SIGNING_IDENTITY}"
    codesign --force --options runtime --timestamp \
        --entitlements "${ENTITLEMENTS}" \
        --sign "${SIGNING_IDENTITY}" "${APP_BUNDLE}"
else
    echo "🔏 Developer ID 인증서 없음 → ad-hoc 서명 (Gatekeeper 경고는 남습니다)"
    codesign --force --options runtime \
        --entitlements "${ENTITLEMENTS}" \
        --sign - "${APP_BUNDLE}"
fi

echo "🔎 Verifying signature..."
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
echo "✅ Signature valid: $(codesign -dv --verbose=2 "${APP_BUNDLE}" 2>&1 | grep -m1 'Signature=')"

if [ -n "${SIGNING_IDENTITY}" ]; then
    echo "✅ App bundle created: ${APP_BUNDLE}"
else
    echo "✅ App bundle created: ${APP_BUNDLE} (ad-hoc)"
fi
echo "🚀 You can launch it using: open ${APP_BUNDLE} or ./scripts/run.sh"
