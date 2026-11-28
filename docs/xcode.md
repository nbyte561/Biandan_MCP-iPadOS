# 在 Xcode 里开发 / 调试

仓库本身是纯 SwiftPM 包（`Package.swift` 一个可执行 target），命令行能编能跑，但 SwiftPM 的
`executableTarget` **不会**打成 `.app`，所以 Xcode 里按 ⌘R 装不进 iPad。要断点调试，用本机的
`BiandanPad.xcodeproj`。

## 打开哪个

```bash
open ~/dev/biandan_pad/BiandanPad/BiandanPad.xcodeproj   # 换成你的路径
```

- 工程里只有一个 app target：iOS 17.0、仅 iPad（`TARGETED_DEVICE_FAMILY = 2`）、`MARKETING_VERSION = 0.1.1`。
- `Sources/BiandanPad` 用 Xcode 16+ 的「同步文件夹」挂在 target 上，**新加文件自动入 target**，不用手动加。
- Info.plist 在 `Support/BiandanPad-Info.plist`，AppIcon 在 `Support/Assets.xcassets`（浅色 + 深色两档）。
- GRDB 用本地包引用 `../vendor/GRDB.swift`，不联网、解析是秒级的。没有 vendor 目录时先：

  ```bash
  git clone --depth 1 --branch v6.29.3 https://github.com/groue/GRDB.swift.git ../vendor/GRDB.swift
  ```

> `.gitignore` 里忽略了 `*.xcodeproj/` 和 `vendor/`：这个工程是**本机开发用**，不随仓库分发。
> 没装 Xcode 工程的人按 README 的 SwiftPM 流程走即可。

## 跑起来

1. target → **Signing & Capabilities** 选自己的 Team，顺手把 Bundle Identifier 改成唯一的（例如 `com.你的名字.BiandanPad`）。
2. iPad 上开 **设置 → 隐私与安全性 → 开发者模式**，首次连线点「信任」。
3. 选设备 → ⌘R。

## 调试开关（环境变量）

在 Scheme → Run → Arguments → Environment Variables 里加：

| 变量 | 作用 |
|---|---|
| `BIANDAN_PAD_DEMO=1` | 跳过华为登录，直接进示例数据；退出在「设置 → 账户 → 退出示例模式」 |
| `BIANDAN_PAD_VIEW=list\|today\|quadrant\|calendar\|stats\|habits\|focus\|conflicts\|import\|inspector` | 启动后直接切到对应页面 |
| `BIANDAN_PAD_SHEET=settings\|newtask` | 启动后直接弹出设置 / 新建任务 |
| `BIANDAN_PAD_SIDEBAR=all` | 启动后强制展开侧栏，用来截竖屏的浮层侧栏 |
| `BIANDAN_PAD_SEARCH_STYLE=legacy` | 强制侧栏搜索框走 iPadOS 17 / 18 的 `UISearchBar` 外观，用来在新系统模拟器上检查旧分支的排版与托底 |
| `BIANDAN_PAD_SEARCH_DRAWER=open` | 启动时不把列表滚到账户卡片，停在搜索框上（默认会藏到账户卡片上面），用来截搜索框的图 |

截图和排查深色模式就靠这套开关：系统外观切深色 + `BIANDAN_PAD_VIEW` 逐个页面看。

## 与命令行构建的关系

`Tools/build_pad_app.sh`（模拟器 .app）和 `Tools/package_ipa.sh`（真机 .ipa）走的是
`swift build --triple ...` + 手工组装 Payload，和 Xcode 工程互不影响：改代码两边都生效，
只是 Xcode 会自带签名、调试器、预览和 Instruments。
