#!/bin/bash
# 把 SPM 编出来的可执行文件组装成可以在 iPad 模拟器里安装运行的 .app。
#
# 用法：Tools/build_pad_app.sh [debug|release]
# 产物：build/BiandanPad.app
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 本地存在 vendor 的 GRDB 就离线构建；没有就让 SwiftPM 从 GitHub 拉（README 里两种都写了）。
if [ -d "$ROOT/../vendor/GRDB.swift" ]; then
  export BIANDAN_VENDOR_GRDB=1
fi
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
TOOLCHAIN_BIN="$(dirname "$(xcrun --find swift)")"
# 允许换一个组装目录，原因同 package_ipa.sh。
OUT="${BIANDAN_BUILD_DIR:-$ROOT/build}"
APP="$OUT/BiandanPad.app"

CONFIGURATION_FILE="/tmp/biandan-ios-dest.json"
cat > "$CONFIGURATION_FILE" <<EOF
{
  "version": 1,
  "toolchain-bin-dir": "$TOOLCHAIN_BIN",
  "target": "arm64-apple-ios17.0-simulator",
  "sdk": "$SDK",
  "extra-cc-flags": [],
  "extra-swiftc-flags": [],
  "extra-cxx-flags": [],
  "extra-cpp-flags": [],
  "extra-ld-flags": []
}
EOF

echo "==> 编译（${CONFIG}，iOS 模拟器 arm64）"
cd "$ROOT"
swift build --disable-sandbox --destination "$CONFIGURATION_FILE" -c "$CONFIG"

if [ "$CONFIG" = "release" ]; then
  PLATFORM_CONFIG="Release"
else
  PLATFORM_CONFIG="Debug"
fi
BIN="$ROOT/.build/out/Products/${PLATFORM_CONFIG}-iphonesimulator/BiandanPad"
[ -f "$BIN" ] || { echo "找不到可执行文件：${BIN}"; exit 1; }

echo "==> 组装 .app"
rm -rf "$APP"
mkdir -p "$APP"
cp "$BIN" "$APP/BiandanPad"
chmod +x "$APP/BiandanPad"

# GRDB 的资源包（迁移脚本等）放在主 bundle 旁边。
if [ -d "$(dirname "$BIN")/GRDB_GRDB.bundle" ]; then
  cp -R "$(dirname "$BIN")/GRDB_GRDB.bundle" "$APP/"
fi

# 图标：和真机包走同一套 actool 资源，浅色 / 深色都能在模拟器里看到。
PARTIAL_PLIST="$OUT/asset-info.plist"
"$ROOT/Tools/make_appicon.sh" "$APP" iphonesimulator 17.0 "$PARTIAL_PLIST"

BUNDLE_VERSION="${BIANDAN_VERSION:-0.1.0}"
BUNDLE_BUILD="${BIANDAN_BUILD:-1}"
cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>便单</string>
    <key>CFBundleExecutable</key>
    <string>BiandanPad</string>
    <key>CFBundleIdentifier</key>
    <string>ai.racore.BiandanPad</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>便单</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${BUNDLE_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUNDLE_BUILD}</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIDeviceFamily</key>
    <array>
        <integer>2</integer>
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

# actool 生成的 CFBundleIcons / CFBundleIconName（含深色图标引用）并进 Info.plist
if [ -f "$PARTIAL_PLIST" ]; then
  /usr/libexec/PlistBuddy -c "Merge ${PARTIAL_PLIST}" "$APP/Info.plist" >/dev/null 2>&1 || true
fi

echo "==> 临时签名"
codesign --force --sign - --timestamp=none "$APP" 2>&1 | tail -2 || true

echo "==> 完成：${APP}"
du -sh "$APP"
