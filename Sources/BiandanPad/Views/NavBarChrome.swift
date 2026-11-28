import SwiftUI

/// 顶栏（导航栏）的滚动边缘样式。
///
/// - iPadOS 17 / 18：系统默认（实心栏 + 底部细线），保持不变；
/// - iPadOS 26 及以上：栏底交回系统（26 是透明栏 + 滚动模糊，27 是实心栏），
///   这里只把滚动边缘指定成 `.soft`（见 `ScrollEdgeEffectStyle`），
///   内容滚到栏下面时是柔和虚化、没有硬边。
///
/// 早先这里还加了 `.toolbarBackground(.hidden, for: .navigationBar)` 想把栏底彻底去掉，
/// 结果 27.2 上顶栏和底栏一起变成「什么都没有」：栏没了、滚动时也没有模糊过渡，反而丢了层次。
/// 只改样式、不动底色才是对的。
struct NavBarChrome: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
