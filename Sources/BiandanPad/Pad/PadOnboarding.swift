import SwiftUI

// MARK: - 新手引导（iPad 版）
//
// 上游 macOS 版用 NSWindow 画聚光灯浮层：记录每个锚点在窗口里的位置，再盖一层高亮洞。
// iPadOS 版第一版不做浮层导览，但保留同一套 API（锚点修饰器、Onboarding 单例、上手清单），
// 这样侧栏、内容区等视图代码不用改，后续要补导览时在这里实现即可。

enum TourTarget: String, Hashable, CaseIterable {
    case sidebar, rowNext7, summary, quickAdd, modeSwitch, selection, newTask, importer, stats, syncBar, account
    /// 桌面浮窗球（macOS 专有，iPad 上不存在）。
    case floatingBall
}

extension View {
    /// 导览锚点：iPad 版暂不绘制浮层，修饰器原样返回。
    func tourAnchor(_ target: TourTarget?) -> some View {
        self
    }
}

/// 上手清单里的一项。
enum ChecklistItem: String, CaseIterable, Identifiable, Sendable {
    case firstTask, quadrant, notifications, importCalendar, ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstTask: return "添加第一条任务"
        case .quadrant: return "看一眼四象限"
        case .notifications: return "打开时间提醒"
        case .importCalendar: return "导入一个外部日历"
        case .ai: return "接入 AI 识别"
        }
    }

    var detail: String {
        switch self {
        case .firstTask: return "在快速添加里输入「明天下午3点 评审」，回车就保存"
        case .quadrant: return "按重要、紧急把任务分进四格，先做要紧的"
        case .notifications: return "允许便单发通知，到点弹出提醒"
        case .importCalendar: return "飞书、iCloud、邮箱日历或 .ics 文件"
        case .ai: return "可选：填 DeepSeek API Key，识别更准"
        }
    }
}

@MainActor
@Observable
final class Onboarding {
    static let shared = Onboarding()

    /// 主界面是否要求重看欢迎页（iPad 版暂不展示）。
    var welcomeReplay = false

    func checklistVisible(on item: SidebarItem) -> Bool { false }

    func mark(_ target: TourTarget) { _ = target }

    func autoStartTourIfNeeded(model: AppModel) { _ = model }

    func startTour(model: AppModel, bringToFront: Bool = false) { _ = (model, bringToFront) }

    func replayWelcome(model: AppModel) { _ = model }

    func showChecklist(model: AppModel, bringToFront: Bool = false) { _ = (model, bringToFront) }

    func resetAll() {}
}
