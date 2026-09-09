#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

echo "🔨 Building latest OhMyFriend..."
./scripts/build_app.sh

echo "🔄 Restarting OhMyFriend..."
killall OhMyFriend 2>/dev/null || true
sleep 0.5

echo "✨ Launching OhMyFriend..."
open OhMyFriend.app
