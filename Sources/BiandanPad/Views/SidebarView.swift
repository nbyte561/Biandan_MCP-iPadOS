import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    /// 搜索框在列表里的行 id，用来把初始滚动位置挪到账户卡片上（见 `revealAccountAtLaunch`）。
    private enum ScrollID {
        static let search = "sidebar.search"
        static let account = "sidebar.account"
    }
    /// 只在第一次出现时把搜索框滚出去，之后切页面回来保持用户自己的滚动位置。
    @State private var didRestoreScroll = false

    var body: some View {
        @Bindable var model = model
        let counts = model.counts
        let conflictCount = model.scheduleConflicts.count

        ScrollViewReader { proxy in
        List(selection: $model.sidebarSelection) {
            // 搜索框和账户卡片都是普通行，跟着「分类」「记录」一起滚：
            // 不再用 safeAreaInset 钉在顶上，也就没有「展开/收起时 inset 变 52pt、
            // 内容被补偿一次」这回事——小屏上滚过头再上滑不会和收起动作打架。
            Section {
                SidebarSearchField(text: $model.searchText, prompt: "搜索标题、备注、子任务")
                    // 左右不额外留边：和下面账户卡片（同样是 0）对齐，框的宽度就是行的宽度。
                    // 17 / 18 的 UISearchBar 自带一圈留白，由控件自己往外补（见 `LegacySearchBar`）。
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .id(ScrollID.search)

                // 账户卡片当成普通一行放在列表里：跟着「分类」「记录」一起滚，
                // 不再用 safeAreaInset 钉在顶上（钉住时它会一直占着一条，列表可视高度也被吃掉）。
                AccountCard()
                    .tourAnchor(.account)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .id(ScrollID.account)
            }

            Section("视图") {
                // 每一行都显式标注 .tag(SidebarItem)：List(selection:) 只按行标签写回选中值，
                // 写死的行没有隐式标签，NavigationLink(value:) 也不会代劳，否则侧栏高亮了但选中值是 nil。
                ForEach(SidebarItem.views, id: \.self) { item in
                    if item == .conflicts {
                        conflictRow(conflictCount)
                    } else {
                        Label(item.title, systemImage: item.systemImage)
                            .badge(badge(for: item, counts: counts))
                            .sidebarDrop(item, model: model)
                            .tourAnchor(item == .next7 ? TourTarget.rowNext7 : nil)
                            .tag(item)
                    }
                }
            }

            Section {
                ForEach(model.snapshot.lists) { list in
                    Label {
                        Text(list.displayName)
                    } icon: {
                        Circle().fill(list.swatch).frame(width: 10, height: 10)
                    }
                    .badge(counts.perList[list.id3] ?? 0)
                    // 把任务卡片拖到待办单上即可移动（多选时整批移动）。
                    .sidebarDrop(.list(list.id3), model: model)
                    .themedContextMenu { close in
                        ListContextMenu(list: list, close: close).environment(model)
                    }
                    // ForEach 按分类编号（String）给行加隐式标签，与选中值类型不符，必须显式标注。
                    .tag(SidebarItem.list(list.id3))
                }
                .onMove { source, destination in
                    var ordered = model.snapshot.lists
                    ordered.move(fromOffsets: source, toOffset: destination)
                    Task { await model.reorderLists(ordered) }
                }
            } header: {
                HStack {
                    Text("分类")
                    Spacer()
                    Button {
                        model.listEditor = ListEditorRequest(list: nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("新建分类")
                    .disabled(model.authState != .signedIn)
                }
            }

            Section("记录") {
                Label(SidebarItem.habits.title, systemImage: SidebarItem.habits.systemImage)
                    .badge(model.habitSummaries.filter(\.needsCheckIn).count)
                    .tag(SidebarItem.habits)
                Label(SidebarItem.focus.title, systemImage: SidebarItem.focus.systemImage)
                    .badge(counts.focusThisWeek)
                    .tag(SidebarItem.focus)
                Label(SidebarItem.stats.title, systemImage: SidebarItem.stats.systemImage)
                    .tag(SidebarItem.stats)
                    .tourAnchor(.stats)
                Label(SidebarItem.importer.title, systemImage: SidebarItem.importer.systemImage)
                    .tag(SidebarItem.importer)
                    .tourAnchor(.importer)
            }
        }
        .listStyle(.sidebar)
        .tourAnchor(.sidebar)
        .modifier(SidebarScrollEdge())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SyncStatusBar().tourAnchor(.syncBar).modifier(SyncFooterChrome())
        }
        .navigationSplitViewColumnWidth(min: 210, ideal: 232, max: 300)
        .onAppear { revealAccountAtLaunch(proxy) }
        .onChange(of: model.searchText.isEmpty) { _, isEmpty in
            // 清空搜索词后把搜索框滚回视野，免得列表恢复成完整菜单、框却还藏在上面。
            guard isEmpty else { return }
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(ScrollID.search, anchor: .top) }
        }
        }
    }

    /// 打开 App 时账户卡片就是第一个按钮，搜索框藏在它上面——想看搜索框往下拉一下。
    /// 不用 inset 的「展开 / 收起」，所以这里只是一次性的滚动位置，不参与任何布局计算。
    private func revealAccountAtLaunch(_ proxy: ScrollViewProxy) {
        guard !didRestoreScroll else { return }
        didRestoreScroll = true
        // 截图 / 排查用：BIANDAN_PAD_SEARCH_DRAWER=open 时停在搜索框上，方便拍它的样子。
        guard ProcessInfo.processInfo.environment["BIANDAN_PAD_SEARCH_DRAWER"] != "open" else { return }
        // List 首次布局还没定就滚，scrollTo 会被随后的布局吃掉一半（实测只滚了 20 多 pt，
        // 搜索框露半截）。稍等一下再滚，滚完再校一次。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            proxy.scrollTo(ScrollID.account, anchor: .top)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                proxy.scrollTo(ScrollID.account, anchor: .top)
            }
        }
    }

    /// 日程冲突：有冲突时图标和数字变红。
    private func conflictRow(_ count: Int) -> some View {
        let icon = count > 0 ? AnyShapeStyle(Theme.overdue) : AnyShapeStyle(.tint)
        let number: Text? = count > 0 ? Text(verbatim: "\(count)").foregroundColor(Theme.overdue).bold() : nil
        return Label {
            Text(SidebarItem.conflicts.title)
        } icon: {
            Image(systemName: SidebarItem.conflicts.systemImage)
                .foregroundStyle(icon)
        }
        .badge(number)
        .help(count > 0 ? "近 30 天有 \(count) 处日程时间重叠" : "近 30 天没有日程冲突")
        .tag(SidebarItem.conflicts)
    }

    private func badge(for item: SidebarItem, counts: SidebarCounts) -> Int {
        switch item {
        case .today: return counts.today
        case .next7: return counts.next7Days
        case .all: return counts.allPending
        case .undated: return counts.undated
        case .collected: return counts.collected
        case .important: return counts.important
        case .completed: return counts.completed
        case .abandoned: return counts.abandoned
        default: return 0
        }
    }
}

struct SyncStatusBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
            switch model.syncStatus {
            case .syncing(let message):
                ProgressView().controlSize(.mini)
                Text(message).lineLimit(1)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.overdue)
                Text(message).lineLimit(2).help(message)
            case .idle where model.isSavingInBackground:
                ProgressView().controlSize(.mini)
                Text(verbatim: "正在保存 \(model.backgroundOperations) 项更改…").lineLimit(1)
            case .idle:
                Circle().fill(Theme.greenDot).frame(width: 8, height: 8)
                if let last = model.lastSyncedAt {
                    Text("已同步 · ") + Text(last, format: .dateTime.hour().minute())
                } else {
                    Text("尚未同步")
                }
            }
            Spacer(minLength: 0)
            Button {
                Task { await model.syncNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(model.syncStatus.isSyncing)
            .help("立即同步（⌘R）")
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Theme.subtext)
        if !model.snapshot.warnings.isEmpty {
            Label("\(model.snapshot.warnings.count) 个数据问题", systemImage: "exclamationmark.bubble")
                .font(.system(size: 11))
                .foregroundStyle(Theme.overdue)
                .help(model.snapshot.warnings.joined(separator: "\n"))
        }
        }
    }
}

/// 侧栏底栏的滚动边缘。
///
/// iPadOS 26 起和顶栏用同一套系统的软边缘（`scrollEdgeEffectStyle(.soft, for: .bottom)`），
/// 列表滚到同步条下面时是柔和虚化而不是一刀切。旧系统这里什么都不做。
struct SidebarScrollEdge: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// 侧栏底部的同步条底座。
///
/// 原来只给了 10pt 外边距就贴在列表上：行内容滚到最下面时会从文字底下穿过去
/// （「已同步 · 11:40」和分类名叠在一起，刷新按钮压住角标），既难读也难点。
/// 现在是一条 `.regularMaterial` 底栏：26 之前带一条顶部细线把边界勾出来；
/// 26 起不再画硬线，边界交给系统的软滚动边缘。
private struct SyncFooterChrome: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content
                .padding(.horizontal, 12)
                .padding(.top, 9)
                .padding(.bottom, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
        } else {
            legacy(content)
        }
        #else
        legacy(content)
        #endif
    }

    private func legacy(_ content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.top, 9)
            .padding(.bottom, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.hairline).frame(height: 0.5)
            }
    }
}
