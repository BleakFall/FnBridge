#!/usr/bin/env bash
# 一键构建 Release、打包 zip、输出 Homebrew cask 所需的 SHA-256。
# 用法:tools/release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="FnBridge.xcodeproj"
SCHEME="FnBridge"
DERIVED="build"

echo "==> 构建 Release ..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$DERIVED" build | tail -3

APP="$DERIVED/Build/Products/Release/$SCHEME.app"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"

OUT="build/FnBridge-${VERSION}.zip"
echo "==> 打包 $OUT ..."
ditto -c -k --keepParent "$APP" "$OUT"

echo
echo "==> SHA-256(填入 Casks/fnbridge.rb 的 sha256):"
shasum -a 256 "$OUT"

echo
echo "下一步:"
echo "  1. git tag v${VERSION} && git push origin v${VERSION}"
echo "  2. 在 GitHub Release 上传 $OUT(文件名须与 cask url 一致)"
echo "  3. 核对 Casks/fnbridge.rb 的 version=${VERSION} 与 sha256 已同步"
