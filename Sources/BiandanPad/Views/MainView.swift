import SwiftUI

/// 主界面：侧栏 / 内容区两栏，详情按需以弹窗出现。
/// 和 macOS 版的差别在于详情不再是常驻右栏（见 InspectorPresenter），
/// 以及标题栏按钮（置顶、全局快捷键在 iPad 上没有）和搜索框的落位。
struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager
    @State private var inspectorInitialized = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// 分栏视图本体。两处样式分支共用，避免重复声明侧栏与内容区。
    private func splitView(showInspector: Binding<Bool>) -> some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView().modifier(NavBarChrome())
        } detail: {
            ContentArea()
                .modifier(InspectorPresenter(isPresented: showInspector))
                .modifier(NavBarChrome())
        }
        .onAppear {
            // 调试：BIANDAN_PAD_SIDEBAR=all 强制展开侧栏，用来截侧栏浮层。
            if ProcessInfo.processInfo.environment["BIANDAN_PAD_SIDEBAR"] == "all" {
                columnVisibility = .all
            }
            // 详情是弹窗，启动时不该自己蹦出来（BIANDAN_PAD_VIEW=inspector 会稍后再打开它）。
            if !inspectorInitialized {
                model.showInspector = false
                inspectorInitialized = true
            }
        }
    }

    var body: some View {
        @Bindable var model = model
        // 窄窗口（竖屏 iPad、窗口模式）用系统的 prominentDetail：侧栏以浮层出现，
        // UIKit 的 oneOverSecondary 会自己压暗内容，和 Apple Music 的手感一致；
        // 并排反而会把内容挤到 600pt 左右，标题栏和四象限被裁。
        GeometryReader { proxy in
            if proxy.size.width >= 1024 {
                splitView(showInspector: $model.showInspector)
                    .navigationSplitViewStyle(.balanced)
            } else {
                splitView(showInspector: $model.showInspector)
                    .navigationSplitViewStyle(.prominentDetail)
            }
        }
        .onAppear { model.undoManager = undoManager }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PomodoroToolbarButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    NotificationCenter.default.post(name: PadSystemUI.openSettings, object: nil)
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("设置")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.toggleInspector()
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help("显示或隐藏详情")
            }
        }
        .sheet(item: $model.newTaskPreset) { preset in
            NewTaskSheet(preset: preset).environment(model)
        }
        .sheet(item: deferToInspector($model.deleteRequest)) { item in
            DeleteTaskSheet(item: item).environment(model)
        }
        .sheet(item: $model.listEditor) { request in
            ListEditorSheet(request: request).environment(model)
        }
        .sheet(item: $model.listDeleteRequest) { list in
            ListDeleteSheet(list: list).environment(model)
        }
        .sheet(isPresented: $model.signOutRequested) {
            SignOutSheet().environment(model)
        }
        .sheet(item: deferToInspector($model.recurrenceRequest)) { task in
            RecurrenceSheet(task: task).environment(model)
        }
        .sheet(item: deferToInspector($model.focusEditor)) { request in
            FocusEditorSheet(request: request).environment(model)
        }
        .sheet(item: deferToInspector($model.focusDeleteRequest)) { record in
            FocusDeleteSheet(record: record).environment(model)
        }
        .sheet(isPresented: $model.batchDeleteRequested) {
            BatchDeleteSheet().environment(model)
        }
    }

    /// 详情弹窗里也能点删除、编辑规则、编辑专注记录。这几张弹层在 InspectorSheet 里另挂了一份，
    /// 根视图这份在详情打开时必须让开：UIKit 同一个 presenter 只能 present 一个，
    /// 两边都挂会互相顶掉（实测根视图抢占失败，连带把详情弹窗也关了）。
    private func deferToInspector<T>(_ binding: Binding<T?>) -> Binding<T?> {
        Binding(get: { model.showInspector ? nil : binding.wrappedValue },
                set: { binding.wrappedValue = $0 })
    }
}

struct ContentArea: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let item = model.sidebarSelection ?? .all
        VStack(spacing: 0) {
            ContentHeader(item: item)
            // 换页时整块一起走：问候卡、快速添加栏、内容一起下沉 / 上浮。
            // 标题栏留在外面当「外框」，换页时它只更新文字，不跟着晃。
            VStack(spacing: 0) {
                // 问候卡片与今日完成率在所有任务视图顶部显示（统计始终是今天），记录页不显示。
                if !item.isRecordPage {
                    TodaySummaryCard(item: item)
                    QuickAddBar()
                }
                Group {
                    if item == .focus {
                        FocusListView()
                    } else if item == .habits {
                        HabitListView()
                    } else if item == .stats {
                        StatsView()
                    } else if item == .importer {
                        ImportView()
                    } else if item == .conflicts {
                        ConflictListView()
                    } else {
                        switch model.effectiveMode {
                        case .list: OccurrenceListView(item: item)
                        case .quadrant: QuadrantView()
                        case .calendar: CalendarView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // 冲突只算一次，卡片按实例 ID 取角标数据。
                .environment(\.conflictIndex, model.conflictIndex)
            }
            // 旧页下沉、新页上浮（系统 blurReplace，见 PageSwap）。
            .modifier(PageSwap(key: PageKey(item: item, mode: model.effectiveMode)))
        }
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            let showBar = model.selectionMode || !model.multiSelection.isEmpty
            VStack(spacing: 8) {
                if showBar {
                    BatchActionBar()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                OperationBanner()
            }
            .animation(.easeInOut(duration: 0.2), value: showBar)
        }
        // 换到别的视图时退出选择模式，免得批量操作作用到看不见的任务上。
        .onChange(of: model.sidebarSelection) { _, _ in
            if model.selectionMode { model.exitSelectionMode() }
        }
    }
}

struct ContentHeader: View {
    @Environment(AppModel.self) private var model
    let item: SidebarItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 竖屏 iPad 宽度有限：先试「标题 + 日期 + 农历」，放不下就退回不带农历的版本。
            ViewThatFits(in: .horizontal) {
                titleCluster(showLunar: true)
                titleCluster(showLunar: false)
                // 更窄（11 寸竖屏、分屏）：连日期都让掉，优先保住右边的分段按钮。
                titleCluster(showLunar: false, showDate: false)
            }
            Spacer(minLength: 8)
            if !item.isRecordPage {
                GlassEffectGroup(spacing: 8) {
                    HStack(spacing: 16) {
                        HeaderSegmented(selection: Binding(get: { model.effectiveMode }, set: { model.setMode($0) }),
                                        options: ContentMode.allCases.map { ThemeOption(value: $0, title: $0.title) }, glass: true)
                            .help("切换视图")

                        if model.effectiveMode == .quadrant {
                            HeaderSegmented(selection: Binding(get: { model.quadrantRange },
                                                               set: { model.quadrantRange = $0 }),
                                            options: QuadrantRange.allCases.map { ThemeOption(value: $0, title: PadTitles.shortTitle($0)) }, glass: true)
                                .help("四象限显示的时间范围")
                        }
                    }
                }
            }
            if !item.isRecordPage {
                SelectionModeButton()
            }
            Button {
                model.newTaskPreset = model.makeNewTaskPreset()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .help("新建任务")
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func titleCluster(showLunar: Bool, showDate: Bool = true) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(model.title(for: item))
                .font(.system(size: 26, weight: .heavy))
                .lineLimit(1)
                .fixedSize()
            if showDate {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    dateText
                    if showLunar {
                        Text(LunarCalendar.headerText(for: model.today) + "·" + LocalDate.weekdayNames[model.today.weekday])
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.label)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var dateText: some View {
        let today = model.today
        let slash = Text("/").foregroundStyle(Theme.accent)
        return (Text(String(today.year)) + slash + Text(String(format: "%02d", today.month))
                + slash + Text(String(format: "%02d", today.day)))
            .font(.system(size: 20, weight: .heavy))
            .lineLimit(1)
            .fixedSize()
    }
}
