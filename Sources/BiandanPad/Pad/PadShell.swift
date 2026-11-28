import SwiftUI

/// 详情的落位：iPad 上只有弹窗这一种。
///
/// macOS 版把它做成右侧常驻栏，是因为 Mac 的窗口够宽。iPad 上站不住：
/// 13 寸横屏 1366 减去 220 侧栏、再切 320 给详情，内容区只剩 800 出头，四象限和标题栏都会被裁；
/// 竖屏（1032）更是直接把详情挤成一条。而且详情栏一旦收起来，点卡片只改选中态、
/// 详情并不会自己冒出来，看起来就像「点待办没反应」。所以这里统一改成 page sheet。
struct InspectorPresenter: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            InspectorSheet()
        }
    }
}

/// 详情弹窗：顶部「详情 / 完成」标题栏 + 检查器本体。
///
/// 检查器里能触发的几个弹层（删除、重复规则、专注编辑 / 删除）必须在这里再挂一份：
/// UIKit 同一层只能 present 一个，根视图那份在弹窗打开时会被挡掉，点了删除会没反应。
/// 挂在弹窗自己的层级里就是叠在弹窗上，实测可用。
struct InspectorSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            InspectorView()
                .navigationTitle("详情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
                .toolbarBackground(Theme.panel, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.accent)
        .modifier(InspectorSheetSizing())
        .presentationBackground(Theme.background)
        .sheet(item: $model.deleteRequest) { item in
            DeleteTaskSheet(item: item).environment(model)
        }
        .sheet(item: $model.recurrenceRequest) { task in
            RecurrenceSheet(task: task).environment(model)
        }
        .sheet(item: $model.focusEditor) { request in
            FocusEditorSheet(request: request).environment(model)
        }
        .sheet(item: $model.focusDeleteRequest) { record in
            FocusDeleteSheet(record: record).environment(model)
        }
    }
}

/// iPadOS 18 起把弹窗撑成整页高：form sheet 只有 620 高，检查器字段多，读起来太局促。
/// 17 上退回 large detent。
private struct InspectorSheetSizing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.presentationSizing(.page)
        } else {
            content.presentationDetents([.large])
        }
    }
}

/// 外观偏好：默认跟随系统，也可以在「设置 → 关于 → 外观」里锁死浅色 / 深色。
enum PadAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let defaultsKey = "pad.appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    /// nil 表示跟随系统。
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 窄屏（竖屏 iPad）上的短标题：分段控件在标题栏里空间有限，「近 7 天」会折成两行。
enum PadTitles {
    static func shortTitle(_ range: QuadrantRange) -> String {
        range == .all ? "全部" : "\(range.rawValue)天"
    }
}
