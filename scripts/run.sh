#!/usr/bin/env bash
set -e

# 풀 Xcode가 있으면 그 툴체인 사용 (CLT에는 SwiftUIMacros 플러그인이 없어 갤러리 빌드 불가)
if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

echo "🔨 Building latest OhMineFriend..."
./scripts/build_app.sh

echo "🔄 Restarting OhMineFriend..."
killall OhMineFriend 2>/dev/null || true
sleep 0.5

echo "✨ Launching OhMineFriend..."
open OhMineFriend.app
