import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - macOS 专有能力的 iPadOS 空实现
//
// 下面这些类型在上游 macOS 版里由菜单栏组件、桌面浮窗球、全局快捷键、设置窗口跳转提供。
// iPadOS 没有菜单栏 / 全局快捷键 / 桌面浮窗这些概念，业务层（AppModel）仍然照旧调用它们，
// 这里给出等价但无副作用的实现，保证 AppModel 与视图代码保持上游原样。

/// 桌面浮窗球（框选识别日程）只在 macOS 上存在。
@MainActor
final class FloatingBallController {
    static let shared = FloatingBallController()
    private init() {}

    func apply(model: AppModel) {
        _ = model
    }
}

/// 菜单栏组件（macOS 才有的常驻菜单项）。
enum MenuBarDefaults {
    static let showKey = "biandan.showMenuBarExtra"

    static var isShown: Bool {
        UserDefaults.standard.object(forKey: showKey) as? Bool ?? true
    }
}

/// 设置页里可以直接跳到的位置（iPad 设置面板用）。
enum SettingsAnchor: String {
    case ai = "settings-ai"
}

/// 全局快速添加的快捷键。iPadOS 上没有跨 App 的全局快捷键，
/// 保留同一套取值只为让「设置」里的选项和保存的值保持一致。
enum QuickAddHotKey: String, CaseIterable, Identifiable, Sendable {
    case controlOptionN, commandOptionN, controlShiftSpace, off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .controlOptionN: return "⌃⌥N"
        case .commandOptionN: return "⌥⌘N"
        case .controlShiftSpace: return "⌃⇧空格"
        case .off: return "关闭"
        }
    }
}

extension AppModel {
    /// iPadOS 注册不了全局快捷键，这里只记录状态，供设置页说明。
    func applyQuickAddHotKey() {
        quickAddHotKeyStatus = nil
    }
}

#if os(iOS)
import UIKit
#endif

/// 「打开华为授权页」这件事在两端的实现不同：macOS 交给系统浏览器，iPadOS 交给 App 内的浏览器面板。
/// 业务层（OAuthFlow）只调用 present，界面上由根视图注册真正的展示动作。
@MainActor
enum PadAuthBrowser {
    static var presenter: ((URL) -> Void)?

    static func present(_ url: URL) {
        if let presenter {
            presenter(url)
            return
        }
        #if os(iOS)
        // 没有注册面板时退回系统浏览器：回调仍在本机 127.0.0.1:42681，只是 App 可能被切到后台。
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}

/// 引导流程的进度点（上游定义在被移除的 macOS 引导浮层里，iPad 版只保留同一个指示器样式）。
struct TourProgressDots: View {
    let index: Int
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { item in
                TourDot(state: item == index ? 0 : (item < index ? 1 : 2))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: index)
    }
}

private struct TourDot: View {
    /// 0 当前，1 已过，2 未到。
    let state: Int

    var body: some View {
        let color: Color = state == 0 ? Theme.accent : (state == 1 ? Theme.accent.opacity(0.45) : Theme.line)
        let width: CGFloat = state == 0 ? 16 : 6
        Capsule().fill(color).frame(width: width, height: 6)
    }
}
