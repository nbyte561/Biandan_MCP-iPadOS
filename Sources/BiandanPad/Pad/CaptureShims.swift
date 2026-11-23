import SwiftUI

/// 识别日程卡片用的语义配色（上游定义在被移除的 macOS 预览面板里，这里只保留颜色表）。
enum DecisionPalette {
    /// 决策模型名：紫色。
    static var decider: Color { Color(hex: 0x8E5BD6) }
    /// 大模型名、放行：蓝色。
    static var model: Color { Quadrant.notImportantUrgent.tint }
    /// 拦下、省下的钱、高于门槛：绿色。
    static var blocked: Color { Theme.done }
    /// 没判断成功、需要留意：橙色。
    static var failed: Color { Color(hex: 0xD9822B) }
    /// 低于门槛：红棕。
    static var low: Color { Color(hex: 0xB5532A) }
    /// 用时：琥珀，和 AI 用量小卡片一致。
    static var time: Color { Color(hex: 0xD99A00) }
    /// 内容类型：浅青；状态：浅粉。
    static var kind: Color { Color(hex: 0x2BB5B0) }
    static var status: Color { Color(hex: 0xD9558C) }
}

/// 带文字的勾选开关：iPadOS 没有 macOS 的 `.checkbox` 样式，用同一套主题画一个胶囊按钮。
struct ThemedSelectionToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOn ? Theme.accent : Theme.subtext)
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(isOn ? Theme.selectionFill : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(isOn ? Theme.accent : Theme.line))
        }
        .buttonStyle(.plain)
    }
}

/// AI 用量统计的分类配色（上游定义在被移除的 macOS 用量页里）。
enum AIUsagePalette {
    static let all: [Color] = [
        Quadrant.notImportantUrgent.tint, Theme.accent, Quadrant.importantUrgent.tint, Quadrant.neither.tint,
        Color(hex: 0x8E5BD6), Color(hex: 0x2BB5B0),
    ]

    static func color(_ index: Int) -> Color { all[index % all.count] }

    static func colors(_ count: Int) -> [Color] { (0..<max(count, 1)).map(color) }
}

/// 文字链接按钮：macOS 用系统的 `.link`，iPadOS 用同一套主题的自绘样式。
struct PadLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PadLinkButtonStyle {
    static var padLink: PadLinkButtonStyle { PadLinkButtonStyle() }
}

extension StatsSubject {
    /// iPad 版暂不提供「AI 用量」分页（识别日程是 macOS 侧的能力）。
    static var padCases: [StatsSubject] { allCases.filter { $0 != .ai } }
}
