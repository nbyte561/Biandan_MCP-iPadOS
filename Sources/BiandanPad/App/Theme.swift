import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// 浅色 / 深色两套值，跟随系统外观（iPad 上由「设置 → 显示与亮度」或控制中心切换）。
    static func adaptive(_ light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
        #else
        return Color(hex: light)
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
#elseif canImport(AppKit)
extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}
#endif

/// 与 UI 原型一致的暖色主题。
///
/// 每个颜色都是「浅色 / 深色」一对：浅色保持原来的米色原型不变，深色用同一套暖调
/// 压暗（近黑的暖灰 + 提亮的强调色），不在深色下换风格。
enum Theme {
    // MARK: 页面骨架

    /// 页面底色。深色下是最暗的一层，卡片 / 面板依次提亮，保证层次。
    static let background = Color.adaptive(0xF4EFE3, dark: 0x15130F)
    static let panel = Color.adaptive(0xFBF8F1, dark: 0x1C1915)
    static let card = Color.adaptive(0xFFFDF8, dark: 0x232019)
    static let line = Color.adaptive(0xE6DFCF, dark: 0x35302A)
    /// 卡片内部的分隔细线（比 line 更浅）。
    static let hairline = Color.adaptive(0xF0EADD, dark: 0x2C2822)
    /// 页面里比背景更凹的一层：分段控件的槽、进度条底槽。
    static let trough = Color.adaptive(0xE8E1D1, dark: 0x100F0C)
    /// 浮起的小块：分段控件选中的滑块、日历里的「今天」外框。
    static let thumb = Color.adaptive(0xFFFFFF, dark: 0x3B3529)
    /// 进度条 / 胶囊的底槽。
    static let track = Color.adaptive(0xE7E0D0, dark: 0x332E26)

    // MARK: 文字

    static let text = Color.adaptive(0x1F1D1A, dark: 0xF2EDE3)
    /// 比 text 稍淡的正文（表单行左侧标签）。
    static let label = Color.adaptive(0x4A453C, dark: 0xD9D2C5)
    static let subtext = Color.adaptive(0x8A8273, dark: 0x9B9384)
    static let fieldName = Color.adaptive(0xB3AA97, dark: 0x8A8272)
    /// 未选中状态的图标 / 圆圈（原来的浅灰棕）。
    static let muted = Color.adaptive(0xB9B09C, dark: 0x6E675B)
    /// 快捷键小胶囊的底色与文字。
    static let chipFill = Color.adaptive(0xEEE8DA, dark: 0x2A2620)
    static let chipText = Color.adaptive(0x6B6457, dark: 0xADA595)
    /// 压在强调色 / 象限色上的文字与图标。浅色下是白字，深色下换成深墨（黄底白字看不清）。
    static let onAccent = Color.adaptive(0xFFFFFF, dark: 0x2A2000)

    // MARK: 强调色

    static let accent = Color.adaptive(0xF5B800, dark: 0xFFC61A)
    /// 多选卡片的浅黄底色（配合 accent 描边）。
    static let selectionFill = Color.adaptive(0xFFF4CC, dark: 0x3B2F0D)
    static let huawei = Color.adaptive(0xCE0E2D, dark: 0xD93A50)
    static let done = Color.adaptive(0x5DB65A, dark: 0x6FCF68)
    static let overdue = Color.adaptive(0xD93025, dark: 0xFF6A5C)
    /// 待定 / 金色文字（象限标题、改期提示）。
    static let gold = Color.adaptive(0xD9A800, dark: 0xF0C42E)
    /// 周末与节假日的红。
    static let weekend = Color.adaptive(0xD9534A, dark: 0xFF7D72)
    /// 警告橙（同步失败、退避中）。
    static let warning = Color.adaptive(0xE8890C, dark: 0xF5A742)
    /// 在线状态点。
    static let greenDot = Color.adaptive(0x34C759, dark: 0x3FDA6A)

    // MARK: 功能色（导入、采集、标注）

    static let purple = Color.adaptive(0x8E5BD6, dark: 0xB08CF0)
    static let orange = Color.adaptive(0xFA8B36, dark: 0xFFA45C)
    static let teal = Color.adaptive(0x2BB5B0, dark: 0x45D6D0)
    static let pink = Color.adaptive(0xD9558C, dark: 0xF074A8)
    static let amber = Color.adaptive(0xD99A00, dark: 0xF0B93A)
    static let rust = Color.adaptive(0xB5532A, dark: 0xD97A4E)
    static let captureFailed = Color.adaptive(0xD9822B, dark: 0xE89A55)
}

extension Quadrant {
    /// 边框与标题色。
    var tint: Color {
        switch self {
        case .importantUrgent: return Color.adaptive(0xE5483A, dark: 0xFF6D5E)
        case .importantNotUrgent: return Color.adaptive(0xE9BC12, dark: 0xF2CE3C)
        case .notImportantUrgent: return Color.adaptive(0x4BA9E0, dark: 0x62B8EA)
        case .neither: return Color.adaptive(0x5DB65A, dark: 0x76C870)
        }
    }

    var titleColor: Color {
        self == .importantNotUrgent ? Theme.gold : tint
    }

    /// 象限底色。
    var fill: Color {
        switch self {
        case .importantUrgent: return Color.adaptive(0xEFDCD3, dark: 0x2E211D)
        case .importantNotUrgent: return Color.adaptive(0xEEE7CB, dark: 0x2B2417)
        case .notImportantUrgent: return Color.adaptive(0xDCE3DF, dark: 0x1A2422)
        case .neither: return Color.adaptive(0xE0E3CC, dark: 0x212318)
        }
    }
}

extension ListColor {
    var color: Color { Color(hex: hex) }
}

extension TodoList {
    var swatch: Color { color.color }
    /// 默认待办单不能改名，云端存的可能是「默认」，统一显示为「未分类」。
    var displayName: String { isDefault ? "未分类" : (favoritesName.isEmpty ? "未命名" : favoritesName) }
}

extension OccurrenceStatus {
    var tint: Color {
        switch self {
        case .pending: return Color.adaptive(0x9A7400, dark: 0xE0B23A)
        case .completed: return Color.adaptive(0x2F8A2B, dark: 0x5ECC58)
        case .abandoned: return Color.adaptive(0x888888, dark: 0x9A9A9A)
        }
    }

    var badgeFill: Color {
        switch self {
        case .pending: return Color.adaptive(0xFFF1C2, dark: 0x3A2F14)
        case .completed: return Color.adaptive(0xDDF0DA, dark: 0x1E3320)
        case .abandoned: return Color.adaptive(0xEEEEEE, dark: 0x2C2C2C)
        }
    }
}

/// 云端字段名的小号等宽标注，与原型中的灰色小字一致。
struct FieldTag: View {
    let name: String
    init(_ name: String) { self.name = name }

    var body: some View {
        Text(name)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Theme.fieldName)
            .lineLimit(1)
    }
}
