import SwiftUI

/// 主界面：侧栏 / 内容区 / 检查器 三栏。iPad 上和 macOS 版是同一套版式，
/// 差别只在标题栏按钮（置顶、全局快捷键在 iPad 上没有）和搜索框的落位。
struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager
    @State private var inspectorAdjusted = false

    var body: some View {
        @Bindable var model = model
        // 检查器宽度固定 372 起，竖屏 iPad 上三栏挤在一起会压扁内容区：
        // 宽度够（横屏 / 大屏）时用右侧常驻栏，不够时改成弹出的面板。
        GeometryReader { proxy in
            let wide = proxy.size.width >= 1024
            NavigationSplitView {
                SidebarView()
            } detail: {
                ContentArea()
                    .modifier(InspectorPresenter(wide: wide, isPresented: $model.showInspector))
            }
            .onAppear {
                // 竖屏时默认不展开检查器（它在这里是弹出面板）。
                if !wide, !inspectorAdjusted {
                    model.showInspector = false
                    inspectorAdjusted = true
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear { model.undoManager = undoManager }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "搜索标题、备注、子任务")
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
                    model.showInspector.toggle()
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help("显示或隐藏检查器")
            }
        }
        .sheet(item: $model.newTaskPreset) { preset in
            NewTaskSheet(preset: preset).environment(model)
        }
        .sheet(item: $model.deleteRequest) { item in
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
        .sheet(item: $model.recurrenceRequest) { task in
            RecurrenceSheet(task: task).environment(model)
        }
        .sheet(item: $model.focusEditor) { request in
            FocusEditorSheet(request: request).environment(model)
        }
        .sheet(item: $model.focusDeleteRequest) { record in
            FocusDeleteSheet(record: record).environment(model)
        }
        .sheet(isPresented: $model.batchDeleteRequested) {
            BatchDeleteSheet().environment(model)
        }
    }
}

struct ContentArea: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let item = model.sidebarSelection ?? .all
        VStack(spacing: 0) {
            ContentHeader(item: item)
            // 问候卡片与今日完成率在所有任务视图顶部显示（统计始终是今天），记录页不显示。
            if !item.isRecordPage {
                TodaySummaryCard(item: item)
            }
            if !item.isRecordPage {
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
        HStack(alignment: .center, spacing: 16) {
            // 竖屏 iPad 宽度有限：先试「标题 + 日期 + 农历」，放不下就退回不带农历的版本。
            ViewThatFits(in: .horizontal) {
                titleCluster(showLunar: true)
                titleCluster(showLunar: false)
            }
            Spacer(minLength: 8)
            if !item.isRecordPage {
                ThemedSegmented(selection: Binding(get: { model.effectiveMode }, set: { model.setMode($0) }),
                                options: ContentMode.allCases.map { ThemeOption(value: $0, title: $0.title) },
                                glass: true)
                    .help("切换视图")

                if model.effectiveMode == .quadrant {
                    ThemedSegmented(selection: Binding(get: { model.quadrantRange },
                                                       set: { model.quadrantRange = $0 }),
                                    options: QuadrantRange.allCases.map { ThemeOption(value: $0, title: PadTitles.shortTitle($0)) },
                                    glass: true)
                        .help("四象限显示的时间范围")
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
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .help("新建任务")
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func titleCluster(showLunar: Bool) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(model.title(for: item))
                .font(.system(size: 26, weight: .heavy))
                .lineLimit(1)
                .fixedSize()
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                dateText
                if showLunar {
                    Text(LunarCalendar.headerText(for: model.today) + "·" + LocalDate.weekdayNames[model.today.weekday])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x3B372F))
                        .lineLimit(1)
                        .fixedSize()
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
