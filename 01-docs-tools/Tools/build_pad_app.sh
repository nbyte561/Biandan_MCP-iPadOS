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
OUT="$ROOT/build"
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

# 图标：官方 1024 图标，模拟器按 CFBundleIconFiles 找这几个尺寸。
ICON_SRC="$ROOT/docs/AppIcon-1024.png"
if [ -f "$ICON_SRC" ]; then
  for size in 60 76 120 152 167; do
    sips -z "$size" "$size" "$ICON_SRC" --out "$APP/AppIcon${size}.png" >/dev/null 2>&1 || true
  done
fi

cat > "$APP/Info.plist" <<'PLIST'
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
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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
    <key>CFBundleIcons</key>
    <dict>
        <key>CFBundlePrimaryIcon</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>AppIcon60</string>
                <string>AppIcon76</string>
                <string>AppIcon120</string>
                <string>AppIcon152</string>
                <string>AppIcon167</string>
            </array>
        </dict>
    </dict>
    <key>UILaunchScreen</key>
    <dict>
        <key>UIColorName</key>
        <string></string>
    </dict>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
    </dict>
    <key>UIRequiresFullScreen</key>
    <false/>
    <key>UIStatusBarStyle</key>
    <string>UIStatusBarStyleDarkContent</string>
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

echo "==> 临时签名"
codesign --force --sign - --timestamp=none "$APP" 2>&1 | tail -2 || true

echo "==> 完成：${APP}"
du -sh "$APP"
