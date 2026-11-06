#!/bin/bash
# 编译「拾页」并装到 ~/Applications。用法：bash build.sh
set -euo pipefail
cd "$(dirname "$0")"

app="$HOME/Applications/拾页.app"
pkill -x Shiye 2>/dev/null || true

mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/Info.plist"
xcrun swiftc -O *.swift -o "$app/Contents/MacOS/Shiye"
codesign --force --sign - "$app"

open "$app"
echo "已安装并启动: $app"
