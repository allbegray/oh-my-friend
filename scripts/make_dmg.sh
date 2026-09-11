#!/usr/bin/env bash
set -e

# 드래그 설치용 DMG 패키징.
#
# 결과물에는 OhMineFriend.app 과 /Applications 심볼릭 링크가 들어가, 사용자가 이미지를 열고
# 앱을 Applications 로 끌어다 놓으면 설치가 끝난다.
#
# 서명·공증은 build_app.sh 가 만든 번들 서명 상태를 그대로 이어받는다:
#   - SIGNING_IDENTITY 가 있으면: DMG 자체도 Developer ID 로 서명하고, 자격증명이 있으면 공증+스테이플.
#   - 없으면: 서명 없이 DMG 만 만든다(Gatekeeper 경고는 남는다).
#
# 공증에 필요한 환경변수(없으면 공증 단계만 건너뛴다):
#   NOTARY_PROFILE                       notarytool 키체인 프로파일 이름
#   또는 NOTARY_APPLE_ID + NOTARY_TEAM_ID + NOTARY_PASSWORD 조합

if [ -z "$DEVELOPER_DIR" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

APP_NAME="OhMineFriend"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}-macOS-arm64.dmg"
VOLUME_NAME="Oh Mine Friend"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "❌ ${APP_BUNDLE} 이 없습니다. 먼저 ./scripts/build_app.sh 를 실행하세요." >&2
    exit 1
fi

# 번들이 실제로 서명되어 있는지 확인 — 서명 안 된 번들을 DMG 로 감싸면
# '손상됨' 판정만 예쁘게 포장될 뿐이다.
if ! codesign --verify --strict "${APP_BUNDLE}" 2>/dev/null; then
    echo "❌ ${APP_BUNDLE} 의 코드 서명이 유효하지 않습니다. build_app.sh 를 다시 실행하세요." >&2
    exit 1
fi

echo "💿 Building ${DMG_NAME}..."

STAGING="$(mktemp -d)"
trap 'rm -rf "${STAGING}"' EXIT

cp -R "${APP_BUNDLE}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

rm -f "${DMG_NAME}"
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING}" \
    -ov -format UDZO \
    "${DMG_NAME}" >/dev/null

echo "✅ DMG created: ${DMG_NAME} ($(du -h "${DMG_NAME}" | cut -f1))"

# ---------------------------------------------------------------
# DMG 서명 (Developer ID 가 있을 때만)
# ---------------------------------------------------------------
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
if [ -z "${SIGNING_IDENTITY}" ]; then
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -m 1 'Developer ID Application' | sed -E 's/^[^"]*"(.*)"$/\1/')" || true
fi

if [ -n "${SIGNING_IDENTITY}" ]; then
    echo "🔐 Signing DMG with Developer ID: ${SIGNING_IDENTITY}"
    codesign --force --timestamp --sign "${SIGNING_IDENTITY}" "${DMG_NAME}"
else
    echo "🔏 Developer ID 인증서 없음 → DMG 미서명 (공증 불가)"
fi

# ---------------------------------------------------------------
# 공증 + 스테이플 (자격증명이 있을 때만)
# ---------------------------------------------------------------
NOTARY_ARGS=()
if [ -n "${NOTARY_PROFILE:-}" ]; then
    NOTARY_ARGS=(--keychain-profile "${NOTARY_PROFILE}")
elif [ -n "${NOTARY_APPLE_ID:-}" ] && [ -n "${NOTARY_TEAM_ID:-}" ] && [ -n "${NOTARY_PASSWORD:-}" ]; then
    NOTARY_ARGS=(--apple-id "${NOTARY_APPLE_ID}" --team-id "${NOTARY_TEAM_ID}" --password "${NOTARY_PASSWORD}")
fi

if [ ${#NOTARY_ARGS[@]} -eq 0 ]; then
    echo "⚠️  공증 자격증명 없음 → 공증 생략. 사용자는 최초 실행 시 Gatekeeper 경고를 봅니다."
    echo "   (README 의 '설치' 항목 참고)"
elif [ -z "${SIGNING_IDENTITY}" ]; then
    echo "⚠️  Developer ID 인증서가 없어 공증을 건너뜁니다 (공증은 Developer ID 서명을 요구합니다)."
else
    echo "📤 Notarizing (수 분 걸립니다)..."
    xcrun notarytool submit "${DMG_NAME}" "${NOTARY_ARGS[@]}" --wait
    echo "📎 Stapling..."
    xcrun stapler staple "${DMG_NAME}"
    xcrun stapler validate "${DMG_NAME}"
    echo "✅ Notarized & stapled: ${DMG_NAME}"
fi
