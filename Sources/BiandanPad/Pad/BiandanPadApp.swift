import SwiftUI
import UniformTypeIdentifiers

/// 便单 for iPadOS 的入口。
///
/// 和 macOS 版共用一套业务层（Core / Store / Sync / MCP / Auth / 视图），
/// 差异集中在三处：窗口外壳（这里）、登录时的浏览器（App 内 WKWebView 面板）、
/// 以及 macOS 专有能力（菜单栏、全局快捷键、桌面浮窗球）的空实现。
@main
struct BiandanPadApp: App {
    @State private var model = AppModel()
    @AppStorage(PadAppearance.defaultsKey) private var appearance = PadAppearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            PadRootView()
                .environment(model)
                .preferredColorScheme(PadAppearance(rawValue: appearance)?.scheme)
                // 设计规范里没有系统蓝：所有系统控件（开关、工具栏按钮、分段高亮）统一用主题黄。
                .tint(Theme.accent)
                .task {
                    if DemoFlags.enabled || model.demoMode { DemoData.seedIfEmpty(into: model) }
                    await model.bootstrap()
                }
        }
    }
}

/// 根视图：未登录看登录页，登录后进主界面。
struct PadRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    @State private var authItem: AuthItem?
    @State private var settingsShown = false
    @State private var shareURL: ShareItem?
    @State private var importingFile = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch model.authState {
            case .checking:
                ProgressView("正在读取本机数据…")
                    .controlSize(.large)
            case .signedOut, .signingIn:
                LoginView()
            case .signedIn:
                MainView()
            }
        }
        .sheet(item: $authItem) { item in
            PadAuthWebView(url: item.url) { authItem = nil }
                .environment(model)
                // 下滑误关会让登录卡在「等待授权」，只能靠「取消」结束。
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $settingsShown) {
            PadSettingsView()
                .environment(model)
                .presentationBackground(Theme.background)
        }
        .sheet(item: $shareURL) { item in
            PadShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $importingFile, allowedContentTypes: [.calendarEvent, .data],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                let granted = url.startAccessingSecurityScopedResource()
                model.loadImportFile(url)
                if granted { url.stopAccessingSecurityScopedResource() }
            }
        }
        .onAppear {
            PadAuthBrowser.presenter = { url in authItem = AuthItem(url: url) }
            applyDebugSelectionIfRequested()
            applyDebugSheetIfRequested()
        }
        .onReceive(NotificationCenter.default.publisher(for: PadSystemUI.openSettings)) { _ in
            settingsShown = true
        }
        .onReceive(NotificationCenter.default.publisher(for: PadSystemUI.exportReady)) { note in
            if let url = note.object as? URL { shareURL = ShareItem(url: url) }
        }
        .onReceive(NotificationCenter.default.publisher(for: PadSystemUI.pickImportFile)) { _ in
            importingFile = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.appBecameActive() }
        }
        .onChange(of: model.authState) { _, state in
            // 登录成功后收起授权面板。
            if state == .signedIn { authItem = nil }
        }
    }
}

extension PadRootView {
    /// 截图/排查用：BIANDAN_PAD_VIEW=list|quadrant|calendar|stats|habits|focus 启动时直接切到对应页面。
    @MainActor
    private func applyDebugSelectionIfRequested() {
        guard let raw = ProcessInfo.processInfo.environment["BIANDAN_PAD_VIEW"], !raw.isEmpty else { return }
        switch raw {
        case "list": model.setMode(.list); model.sidebarSelection = .all
        case "today": model.setMode(.list); model.sidebarSelection = .today
        case "quadrant": model.setMode(.quadrant)
        case "calendar": model.setMode(.calendar)
        case "stats": model.sidebarSelection = .stats
        case "habits": model.sidebarSelection = .habits
        case "focus": model.sidebarSelection = .focus
        case "conflicts": model.sidebarSelection = .conflicts
        case "import": model.sidebarSelection = .importer
        case "inspector":
            // 等 bootstrap 把数据灌进来再选中第一条，用来截详情弹窗。
            model.setMode(.list); model.sidebarSelection = .all
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                model.selectedOccurrenceID = model.snapshot.occurrences.first?.id
                model.showInspector = true
            }
        default: break
        }
    }
}

extension PadRootView {
    /// 截图/排查用：BIANDAN_PAD_SHEET=settings 启动时直接弹出设置面板。
    @MainActor
    private func applyDebugSheetIfRequested() {
        guard let raw = ProcessInfo.processInfo.environment["BIANDAN_PAD_SHEET"], !raw.isEmpty else { return }
        switch raw {
        case "settings": settingsShown = true
        case "newtask": model.newTaskPreset = model.makeNewTaskPreset()
        default: break
        }
    }
}

/// sheet(item:) 需要 Identifiable：授权页 URL 和导出文件 URL 各包一层。
struct AuthItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// 系统分享面板（导出文件后存到「文件」）。
struct PadShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}


