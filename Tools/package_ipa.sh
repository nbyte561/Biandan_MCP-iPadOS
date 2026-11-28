#!/bin/bash
# 打包成可以自签安装的 .ipa（真机 arm64，iPhoneOS SDK）。
#
# 用法：
#   Tools/package_ipa.sh                # 用默认 bundle id
#   BIANDAN_BUNDLE_ID=com.yourname.biandan Tools/package_ipa.sh
#
# 产物：dist/BiandanPad-<版本>.ipa
# 说明：这里只做 ad-hoc 签名，拿到的 .ipa 不能直接装，需要用 Sideloadly / AltStore /
#       ESign / 爱思助手 之类用你自己的证书重签。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 本地存在 vendor 的 GRDB 就离线构建；没有就让 SwiftPM 从 GitHub 拉（README 里两种都写了）。
if [ -d "$ROOT/../vendor/GRDB.swift" ]; then
  export BIANDAN_VENDOR_GRDB=1
fi
CONFIG="${CONFIG:-release}"
BUNDLE_ID="${BIANDAN_BUNDLE_ID:-ai.racore.BiandanPad}"
VERSION="${BIANDAN_VERSION:-0.1.0}"
BUILD_NUMBER="${BIANDAN_BUILD:-1}"
APP_NAME="便单"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
TOOLCHAIN_BIN="$(dirname "$(xcrun --find swift)")"
# 允许换一个组装目录：某些环境（沙箱、受管机器）会拦住 build/ 下的删除，
# 导致 actool / codesign 没法替换旧文件、留下 ~tmp 和 .cstemp 残渣。
OUT="${BIANDAN_BUILD_DIR:-$ROOT/build/device}"
APP="$OUT/Payload/BiandanPad.app"
DIST="${BIANDAN_DIST_DIR:-$ROOT/dist}"

if [ "$CONFIG" = "release" ]; then PLATFORM_CONFIG="Release"; else PLATFORM_CONFIG="Debug"; fi

echo "==> 编译（${CONFIG}，真机 arm64 / iOS 17.0）"
cd "$ROOT"
# 注意：这里必须用 --triple + --sdk，不能用 --destination。这套工具链上的 SwiftPM
# 会把 destination 里 arm64-apple-ios17.0 静默忽略，退回宿主 macOS 目标，
# 编出来的二进制装不进 iPad（现象是报 onContinuousHover 只在 macOS 14 可用）。
swift build --disable-sandbox -c "$CONFIG" \
  --triple arm64-apple-ios17.0 \
  --sdk "$SDK"

BIN="$ROOT/.build/out/Products/${PLATFORM_CONFIG}-iphoneos/BiandanPad"
[ -f "$BIN" ] || { echo "找不到可执行文件：${BIN}"; exit 1; }

echo "==> 组装 Payload"
rm -rf "$OUT"
mkdir -p "$APP"
cp "$BIN" "$APP/BiandanPad"
chmod +x "$APP/BiandanPad"

# GRDB 的资源包（迁移脚本等）
if [ -d "$(dirname "$BIN")/GRDB_GRDB.bundle" ]; then
  cp -R "$(dirname "$BIN")/GRDB_GRDB.bundle" "$APP/"
fi

# 图标：浅色 + 深色两套，交给 actool 编成 Assets.car。
# 散装 PNG + CFBundleIconFiles 只能声明一套，深色模式下系统会垫底板（见 Tools/make_appicon.sh 注释）。
echo "==> 编图标（浅色 + 深色）"
PARTIAL_PLIST="$OUT/asset-info.plist"
"$ROOT/Tools/make_appicon.sh" "$APP" iphoneos 17.0 "$PARTIAL_PLIST"

echo "==> 写 Info.plist"
cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>BiandanPad</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>MinimumOSVersion</key>
    <string>17.0</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>2</integer>
    </array>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
    </dict>
    <key>UIRequiresFullScreen</key>
    <false/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>127.0.0.1</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
        </dict>
    </dict>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>导入系统日历时需要读取你已有的日程。</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>便单的本机 MCP 服务需要局域网访问，供同一 Wi-Fi 下的电脑连接。</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_biandan-mcp._tcp</string>
    </array>
</dict>
</plist>
PLIST

# 把 actool 生成的图标键（CFBundleIcons / CFBundleIcons~ipad）并进来
if [ -f "$PARTIAL_PLIST" ]; then
  /usr/libexec/PlistBuddy -c "Merge ${PARTIAL_PLIST}" "$APP/Info.plist" >/dev/null 2>&1 || true
fi

echo "==> ad-hoc 签名"
# 自签工具会覆盖这层签名；先签一遍保证 bundle 结构完整、能被 codesign 校验通过。
codesign --force --timestamp=none --sign - "$APP" 2>&1 | tail -2 || true

echo "==> 打 zip 成 .ipa"
mkdir -p "$DIST"
IPA="$DIST/BiandanPad-${VERSION}.ipa"
rm -f "$IPA"
(cd "$OUT" && zip -qry "$IPA" Payload)

echo
echo "==> 完成：${IPA}"
ls -lh "$IPA"
echo "--- 二进制校验 ---"
file "$APP/BiandanPad"
lipo -info "$APP/BiandanPad"
xcrun vtool -show-build "$APP/BiandanPad" 2>/dev/null | grep -E "platform|minos|sdk" || true
echo "--- bundle id / 版本 ---"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Info.plist"
