import SwiftUI

/// 换页的身份：侧栏项 + 视图模式。任一变化都算换了一页。
struct PageKey: Hashable {
    let item: SidebarItem
    let mode: ContentMode
}

extension AnyTransition {
    /// 换页的「下沉 / 上浮」：旧页缩小、淡出，新页从略小放大回原尺寸、淡入。
    ///
    /// 最早用的是系统 `blurReplace(.downUp)`，方向感更准，但在长列表上代价太大：
    /// 200 条任务、当前页 80 条时实测平均 48–53fps、单帧最长 139ms、每次切换丢 11–17 帧
    /// （iPad Air M1 上就是肉眼可见的卡）。现在只动 `scale` / `opacity` 两个可合成属性，
    /// 没有离屏模糊；同样条件下平均 55–58fps、单帧最长 43–75ms，和「不做动画」的重建开销基本持平。
    static var pageSink: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.98))
    }
}

/// 换页转场。页面的「身份」由 `PageKey` 决定，key 一变就换一棵子树，转场交给系统播放。
///
/// - 0.2 秒 + `easeOut`：快到不挡手，但还看得见一点位移（B 站 / Apple Music 那种「迅速但有一点点微动画」）。
/// - 只在 iPadOS 18 起启用；17 上、以及系统开了「减弱动态效果」时退回纯淡入淡出，不做缩放。
/// - 触发点统一挂在容器的 `.animation(_:value:)` 上：侧栏点击、键盘切换、工具栏换模式都走这里，
///   不用在每个调用点写 `withAnimation`。
struct PageSwap: ViewModifier {
    let key: PageKey
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            swapped(content)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.2), value: key)
    }

    @ViewBuilder
    private func swapped(_ content: Content) -> some View {
        if reduceMotion {
            content.id(key).transition(.opacity)
        } else if #available(iOS 18.0, macOS 15.0, *) {
            content.id(key).transition(.pageSink)
        } else {
            content.id(key).transition(.opacity)
        }
    }
}
