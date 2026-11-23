import SwiftUI

/// 检查器在 iPad 上的两种落位：
/// - 宽度够（横屏、大屏）：右侧常驻一栏，和 macOS 版一致；
/// - 宽度不够（竖屏 iPad）：改成弹出的面板，避免三栏互相挤压。
struct InspectorPresenter: ViewModifier {
    let wide: Bool
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        if wide {
            content.inspector(isPresented: $isPresented) {
                InspectorView()
                    .inspectorColumnWidth(min: 320, ideal: 360, max: 460)
            }
        } else {
            content.sheet(isPresented: $isPresented) {
                InspectorView()
                    .presentationDetents([.large])
            }
        }
    }
}

/// 窄屏（竖屏 iPad）上的短标题：分段控件在标题栏里空间有限，「近 7 天」会折成两行。
enum PadTitles {
    static func shortTitle(_ range: QuadrantRange) -> String {
        range == .all ? "全部" : "\(range.rawValue)天"
    }
}
