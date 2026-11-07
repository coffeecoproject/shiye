#!/bin/bash
# 编译「拾页」。
#   bash build.sh        编译本机版本，装到 ~/Applications 并启动
#   bash build.sh dist   编译 Apple 芯片和 Intel 通用版，打包成 dist/拾页-<版本>.zip，用来发给别人
set -euo pipefail
cd "$(dirname "$0")"

ver=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
min=$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' Info.plist)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 把程序编进 $1 指定的 .app，后面的参数是要编的芯片架构
build() {
  local app=$1; shift
  local bins=()
  mkdir -p "$app/Contents/MacOS"
  cp Info.plist "$app/Contents/Info.plist"
  for arch in "$@"; do
    xcrun swiftc -O -target "$arch-apple-macos$min" *.swift -o "$tmp/Shiye-$arch"
    bins+=("$tmp/Shiye-$arch")
  done
  lipo -create "${bins[@]}" -output "$app/Contents/MacOS/Shiye"
  codesign --force --sign - "$app"
}

if [[ ${1:-} == dist ]]; then
  build "$tmp/拾页.app" arm64 x86_64
  mkdir -p dist
  zip="dist/拾页-$ver.zip"
  rm -f "$zip"
  ditto -c -k --keepParent "$tmp/拾页.app" "$zip"
  echo "已打包: $PWD/$zip"
else
  app="$HOME/Applications/拾页.app"
  pkill -x Shiye 2>/dev/null || true
  build "$app" "$(uname -m)"
  open "$app"
  echo "已安装并启动: $app"
fi
