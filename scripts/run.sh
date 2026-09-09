#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

if [ ! -d "OhMyFriend.app" ]; then
    ./scripts/build_app.sh
fi

echo "✨ Launching OhMyFriend..."
open OhMyFriend.app
