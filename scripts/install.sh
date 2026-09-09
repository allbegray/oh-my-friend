#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

echo "🔨 Building OhMyFriend (Release)..."
./scripts/build_app.sh

APP_NAME="OhMyFriend.app"
DEST_DIR="/Applications"

# Check write permission for /Applications, fallback to ~/Applications
if [ ! -w "$DEST_DIR" ]; then
    DEST_DIR="$HOME/Applications"
    mkdir -p "$DEST_DIR"
fi

TARGET_PATH="${DEST_DIR}/${APP_NAME}"

echo "📦 Installing ${APP_NAME} to ${DEST_DIR}..."
# Stop running instance if any
killall OhMyFriend 2>/dev/null || true

# Copy
rm -rf "$TARGET_PATH"
cp -R "$APP_NAME" "$DEST_DIR/"

echo "✅ Successfully installed to: ${TARGET_PATH}"
echo ""
echo "🎉 You can now launch 'Oh My Friend' via Spotlight (Cmd + Space) or by running:"
echo "   open \"${TARGET_PATH}\""
echo ""

# Ask to run
read -p "🚀 Do you want to launch Oh My Friend now? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    open "$TARGET_PATH"
fi
