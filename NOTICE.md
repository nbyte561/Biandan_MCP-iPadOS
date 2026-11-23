# 来源、版权与许可

## 代码来源

本仓库将 [yingcaihuang/biandan_MCP-main](https://github.com/yingcaihuang/biandan_MCP-main) 中的
macOS 客户端（`BiandanMac/`，SwiftUI + GRDB）移植到 iPadOS 的结果。

- 业务层（`Core/` `Store/` `Sync/` `Cloud/` `MCP/`）原样复用上游代码；
- 平台差异集中在 `Sources/BiandanPad/Pad/`，另有 26 个上游文件做了条件编译级别的小改；
- 每个文件是否改动、改了什么，见 [README 的「改动清单」](README.md#改动清单)。

## 许可

上游仓库 `biandan_MCP-main` **没有 LICENSE 文件**（GitHub 识别为「无许可证」），按著作权默认规则是
「保留所有权利」。不过作者与开发团队对这次移植的态度是明确支持的。


据此，本仓库的定位与边界：

| 场景 | 说明 |
|---|---|
| 学习、研究及自行签名安装 | 无需另行取得许可 |
| 提交 PR、发布 issue 或参与共同修复 | 无需另行取得许可 |
| 保留署名后转载或分享仓库链接 | 请保留对上游的署名与链接 |
| 商业使用，或将上游代码再分发至其他产品 | 仍建议事先与作者确认；在无正式许可证的情况下，此属需单独取得授权之范畴 |

若macOS客户端作者未来为上游补上正式许可证（例如 MIT），本仓库会跟进采用同一许可，并更新本节。

## 第三方依赖

| 依赖 | 许可证 | 引入方式 |
|---|---|---|
| [GRDB.swift](https://github.com/groue/GRDB.swift) v6.29.3 | MIT | SwiftPM 远程依赖，本仓库不含其源码 |

## 商标与素材

- 「便单」名称、App 图标（`docs/AppIcon-1024.png`）、界面视觉规范（上游 `DESIGN.md`）的权利归原作者/权利人所有，
  这里仅用于标识「这是便单 macOS 版的移植」，若权利人要求会立即移除。
- 本仓库与华为、与便单官方均无关联，属于第三方实验性移植。
