#!/usr/bin/env bash
set -e

# 자동 업데이트용 ZIP 생성.
#
# UpdateManager 는 이 ZIP 을 내려받아 `ditto -xk` 로 풀고, 최상위의 `.app` 번들을 골라
# 현재 설치본 자리를 덮어쓴다. 그래서 ZIP 은 반드시 번들을 **최상위에** 담아야 한다
# (`ditto --keepParent`). 압축도 `ditto` 로 하는 이유는 확장 속성·리소스 포크를 보존해
# 서명이 왕복에서 깨지지 않게 하기 위함이며, 해제(`ditto -xk`)와 대칭이다.
#
# LEGACY_APP_NAME 을 지정하면 그 이름의 앱 사본을 ZIP 안에 하나 더 넣는다.
# 앱 이름을 바꾼 릴리스에서 **구버전 앱의 업데이터가 옛 이름을 찾기 때문**이다
# (구버전은 `lastPathComponent == "<옛 이름>.app"` 로 찾는다). 신버전 업데이터는
# 이름에 의존하지 않으므로, 이 옵션은 전환 릴리스 한 번만 쓰고 그 다음 릴리스에서 제거한다.

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

APP_NAME="OhMineFriend"
APP_BUNDLE="${APP_NAME}.app"
ZIP_NAME="${APP_NAME}-macOS-arm64.zip"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "❌ ${APP_BUNDLE} 이 없습니다. 먼저 ./scripts/build_app.sh 를 실행하세요." >&2
    exit 1
fi

if ! codesign --verify --strict "${APP_BUNDLE}" 2>/dev/null; then
    echo "❌ ${APP_BUNDLE} 의 코드 서명이 유효하지 않습니다. build_app.sh 를 다시 실행하세요." >&2
    exit 1
fi

echo "🗜️  Building ${ZIP_NAME}..."

if [ -n "${LEGACY_APP_NAME:-}" ] && [ "${LEGACY_APP_NAME}" != "${APP_BUNDLE}" ]; then
    STAGING="$(mktemp -d)"
    trap 'rm -rf "${STAGING}"' EXIT
    cp -R "${APP_BUNDLE}" "${STAGING}/"
    cp -R "${APP_BUNDLE}" "${STAGING}/${LEGACY_APP_NAME}"
    echo "   ↳ 구버전 업데이터 호환용 사본 포함: ${LEGACY_APP_NAME}"
    rm -f "${ZIP_NAME}"
    ditto -c -k --sequesterRsrc --keepParent "${STAGING}/${APP_BUNDLE}" "${ZIP_NAME}"
    # -k 로 만든 zip 에 형제 항목을 추가한다 (BSD zip 의 -g 는 기존 아카이브에 append).
    ( cd "${STAGING}" && zip -q -r -y "${DIR}/${ZIP_NAME}" "${LEGACY_APP_NAME}" )
else
    rm -f "${ZIP_NAME}"
    ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_NAME}"
fi

echo "✅ ZIP created: ${ZIP_NAME} ($(du -h "${ZIP_NAME}" | cut -f1))"
