#!/usr/bin/env bash
# 在 macOS 上本地构建未签名 IPA（Windows 上请用 GitHub Actions）。
# 产物：../../ipa/7/OJHelper-<ver>-<build>-unsigned.ipa 与 sha256.txt
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "需要 XcodeGen: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate

xcodebuild \
  -project OJHelper.xcodeproj \
  -scheme OJHelper \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP="build/Build/Products/Release-iphoneos/OJHelper.app"
VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Info.plist")
NAME="OJHelper-${VER}-${BUILD}-unsigned.ipa"

rm -rf out
mkdir -p out/Payload
cp -R "$APP" out/Payload/
(cd out && zip -qry "$NAME" Payload)

OUTDIR="../../ipa/7"
mkdir -p "$OUTDIR"
cp "out/$NAME" "$OUTDIR/"
(cd "$OUTDIR" && shasum -a 256 "$NAME" > sha256.txt)

echo "wrote $OUTDIR/$NAME"
cat "$OUTDIR/sha256.txt"