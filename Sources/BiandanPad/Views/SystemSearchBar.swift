import SwiftUI
import UIKit

/// 侧栏顶部的搜索框，按系统版本走两套外观，两套都是系统渲染的控件：
///
/// - iPadOS 17 / 18：系统的 `UISearchBar`（灰色小圆角搜索框，带清除按钮、取消逻辑、键盘行为），
///   只把文字双向绑到 `AppModel.searchText`；
/// - iPadOS 26 起：系统那套「圆角液态玻璃搜索框」只有放进导航栏时才会由 `UISearchBar`
///   自动渲染，而这个 App 的侧栏没有导航栏（标题栏是内容区自绘的），所以 26+ 用 `TextField`
///   承载输入，外观交给系统的 `glassEffect(.regular.interactive(), in: Capsule())`——
///   和系统玻璃按钮、分段按钮同一条渲染路径。
///
/// 它是侧栏 `List` 的第一行，和账户卡片、菜单项一样随滚动走：
/// 打开 App 时滚到账户卡片，搜索框就藏在它上面，往下拉一下才露出来；往上滚它自己滚回去。
/// 早先用的是 `safeAreaInset` 的「展开 / 收起」，但只要它占的 inset 会变，
/// 收起时那 52pt 的内容补偿就会和手指滚动抢，小屏上滚过头再上滑会明显抽一下，所以换成纯滚动。
///
/// 为什么不用 SwiftUI 的 `.searchable`：它在 iPad 上必须落在导航栏里（导航栏抽屉，或侧栏那列的
/// 导航栏 section）。实测把 `.searchable` 挂在分栏视图、侧栏 List、列内 NavigationStack，
/// 以及 `.sidebar` / `.navigationBarDrawer` / `.automatic` 各种 placement 上都不渲染搜索框；
/// 最近一次（去掉栏底干预后）再试，侧栏会多长出一条导航栏、并把分栏的侧栏开关挤没。
struct SidebarSearchField: View {
    @Binding var text: String
    var prompt: String

    var body: some View {
        Group {
            if #available(iOS 26.0, *), !forcesLegacy {
                GlassSearchField(text: $text, prompt: prompt)
            } else {
                LegacySearchBar(text: $text, prompt: prompt)
                    // UISearchBar 的搜索框自带左右各 8pt 的边（它内部有个固定内距），
                    // 光把行边距归零还是比账户卡片窄一圈，这里把控件本身往外推同样的距离，
                    // 灰色框才会和上下选项对齐。控件背景是清空的，多出去的部分看不见。
                    .padding(.horizontal, -LegacySearchBar.sideMargin)
            }
        }
        // 行高固定，两套外观在同一条高度里居中，滚动时不会一高一低。
        .frame(height: 40)
    }

    /// `BIANDAN_PAD_SEARCH_STYLE=legacy` 可以强制走旧外观，
    /// 用来在只有新系统的模拟器上检查 17 / 18 那条分支。
    private var forcesLegacy: Bool {
        ProcessInfo.processInfo.environment["BIANDAN_PAD_SEARCH_STYLE"] == "legacy"
    }
}

// MARK: - iPadOS 26+：玻璃胶囊

@available(iOS 26.0, *)
private struct GlassSearchField: View {
    @Binding var text: String
    var prompt: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
            TextField("", text: $text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .animation(.easeOut(duration: 0.15), value: text.isEmpty)
    }
}

// MARK: - iPadOS 17 / 18：系统 UISearchBar

private struct LegacySearchBar: UIViewRepresentable {
    /// 系统搜索框左右自带的内距，用来把控件抵出去，和侧栏其他选项对齐。
    static let sideMargin: CGFloat = 8

    @Binding var text: String
    var prompt: String

    func makeUIView(context: Context) -> UISearchBar {
        let bar = UISearchBar()
        bar.delegate = context.coordinator
        bar.placeholder = prompt
        bar.searchBarStyle = .default
        // 去掉搜索栏自带的那层白底（侧栏已经有自己的背景），只留灰色的搜索框本身。
        bar.backgroundImage = UIImage()
        bar.backgroundColor = .clear
        bar.autocapitalizationType = .none
        bar.autocorrectionType = .no
        bar.returnKeyType = .search
        // 让它在侧栏里横向铺满，而不是按内容宽度居中。
        bar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bar.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return bar
    }

    func updateUIView(_ bar: UISearchBar, context: Context) {
        if bar.text != text { bar.text = text }
    }

    /// UISearchBar 自带上下留白，压到搜索框本身的高度，和玻璃那条对齐。
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISearchBar, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.intrinsicContentSize.width
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UISearchBarDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func searchBar(_ bar: UISearchBar, textDidChange searchText: String) {
            text.wrappedValue = searchText
        }

        func searchBarSearchButtonClicked(_ bar: UISearchBar) {
            bar.resignFirstResponder()
        }
    }
}
