import SwiftUI

// MARK: - 主题菜单：iPadOS 上的长按版本
//
// 上游 macOS 版用右键（或 Control+点击）在鼠标位置弹出主题面板，靠 NSEvent 本地监听 + NSView 命中测试实现。
// iPadOS 没有右键，这里改用「长按卡片」弹出同一个 ThemedMenuPanel：面板组件、配色、分组规则完全沿用
// DESIGN.md 里的规范，只把触发方式和定位方式换成触屏逻辑。

/// 长按弹出主题面板。`menu` 收到一个 close 回调，执行操作前先调用它收起面板。
private struct PadContextMenuModifier<MenuContent: View>: ViewModifier {
    let onOpen: (() -> Void)?
    let menu: (@escaping () -> Void) -> MenuContent
    @State private var open = false

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0.35) {
                onOpen?()
                open = true
            }
            // iPad 上 popover 是真正的气泡；iPhone 上系统会自动降级成 sheet。
            .popover(isPresented: $open, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                menu { open = false }
                    .presentationCompactAdaptation(.popover)
            }
    }
}

extension View {
    func themedContextMenu<MenuContent: View>(onOpen: (() -> Void)? = nil,
                                              @ViewBuilder menu: @escaping (_ close: @escaping () -> Void) -> MenuContent) -> some View {
        modifier(PadContextMenuModifier(onOpen: onOpen, menu: menu))
    }
}

/// 等弹出面板收起后再执行（例如打开弹窗），避免和 popover 的关闭动画冲突。
func afterMenuCloses(_ body: @escaping @MainActor () -> Void) {
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(180))
        body()
    }
}

// MARK: - 面板组件

/// 弹出面板外框：可选的标题（左侧色条）+ 分组卡片。
struct ThemedMenuPanel<Content: View>: View {
    let title: String?
    let subtitle: String?
    let tint: Color
    let content: Content

    init(title: String? = nil, subtitle: String? = nil, tint: Color = Theme.accent,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tint)
                        .frame(width: 4, height: subtitle == nil ? 16 : 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 13.5, weight: .heavy))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.subtext)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
            }
            content
        }
        .padding(10)
        .frame(width: 270)
        .popoverBackground(Theme.panel)
    }
}

/// 一组菜单行，放在白色卡片里。
struct ThemedMenuGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) { content }.themedCard()
    }
}

struct ThemedMenuSeparator: View {
    var body: some View {
        Rectangle().fill(Color(hex: 0xF0EADD)).frame(height: 1).padding(.leading, 46)
    }
}

struct ThemedMenuCaption: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.subtext)
            .padding(.leading, 2)
            .padding(.top, 2)
    }
}

/// 带颜色圆点的选择行（待办单）。
struct ThemedMenuListRow: View {
    let color: Color
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 10, height: 10).frame(width: 26)
                Text(title)
                    .font(.system(size: 13, weight: selected ? .bold : .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(selected ? Theme.accent.opacity(0.14) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 只屏蔽点击，不用 .disabled（会把选中项调淡）。
        .allowsHitTesting(!selected)
    }
}

/// 2×2 象限色块（菜单里的「移到象限」）。当前象限打勾、不可点。
struct QuadrantMiniGrid: View {
    let current: Quadrant?
    let onPick: (Quadrant) -> Void

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                chip(.importantUrgent)
                chip(.importantNotUrgent)
            }
            GridRow {
                chip(.notImportantUrgent)
                chip(.neither)
            }
        }
    }

    private func chip(_ quadrant: Quadrant) -> some View {
        let on = quadrant == current
        return Button {
            onPick(quadrant)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(quadrant.tint)
                Text(quadrant.title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(quadrant.titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(quadrant.fill))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(quadrant.tint.opacity(on ? 1 : 0.4), lineWidth: on ? 2 : 1))
            .shadow(color: quadrant.tint.opacity(on ? 0.25 : 0), radius: 3, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!on)
    }
}

// MARK: - 任务卡片的菜单面板

/// 小号胶囊按钮（菜单里的快捷改期）。
struct ThemedMenuChip: View {
    let title: String
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint == Theme.subtext ? Theme.subtext : Theme.text)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.line))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 面板底部的一排图标按钮（图标 + 小字），用来把次要操作压成一行。
struct ThemedMenuIconButton: View {
    let icon: String
    let title: String
    var tint: Color = Theme.accent
    var destructive = false
    let action: () -> Void

    var body: some View {
        let labelColor: Color = destructive ? Theme.overdue : Theme.subtext
        return Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(tint.opacity(0.15))
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 28, height: 26)
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct OccurrenceContextMenu: View {
    @Environment(AppModel.self) private var model
    let item: OccurrenceItem
    let close: () -> Void

    private func run(_ action: @escaping @MainActor () async -> Void) {
        close()
        Task { @MainActor in await action() }
    }

    /// 下一个周一（今天是周一时取下周一）。
    static func nextMonday(after day: LocalDate) -> LocalDate {
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: day.date()) // 1 = 周日，2 = 周一
        let offset = (9 - weekday) % 7
        return day.adding(days: offset == 0 ? 7 : offset)
    }

    /// 快捷改期：保留原来的持续天数和时刻。重复任务只改这一次（脱离系列）。
    private func moveDate(to day: LocalDate) {
        var span = 0
        if !item.task.undated, let start = item.occurrence.startDate, let end = item.occurrence.endDate {
            span = max(start.days(to: end), 0)
        }
        let end = day.adding(days: span)
        let target = item
        run { await model.reschedule(target, start: day, end: end, startTime: nil, endTime: nil) }
    }

    var body: some View {
        let task = item.task
        let subtitle = item.scheduleText(today: model.today) + (task.isRepeating ? " · " + RuleSummary.describe(task) : "")
        ThemedMenuPanel(title: task.taskTitle.isEmpty ? "（无标题）" : task.taskTitle, subtitle: subtitle,
                        tint: task.quadrant.tint) {
            statusGroup
            if item.status == .pending {
                rescheduleSection
            }
            ThemedMenuCaption("移到象限")
            QuadrantMiniGrid(current: task.quadrant) { quadrant in
                let id = item.id
                run { await model.moveToQuadrant(occurrenceID: id, quadrant) }
            }
            listSection
            toolbar
        }
    }

    // MARK: 状态

    @ViewBuilder
    private var statusGroup: some View {
        let progress = item.progress
        ThemedMenuGroup {
            switch item.status {
            case .pending:
                ThemedMenuRow(icon: "checkmark", title: "完成本次", tint: Theme.done) {
                    run { await model.toggleCompletion(item) }
                }
                ThemedMenuSeparator()
                ThemedMenuRow(icon: "slash.circle", title: "放弃本次", tint: Theme.subtext) {
                    run { await model.abandon(item) }
                }
                if progress.completedCount > 0 {
                    ThemedMenuSeparator()
                    ThemedMenuRow(icon: "arrow.counterclockwise", title: "清零进度",
                                  detail: "已完成 \(progress.completedCount) / \(progress.targetCount)",
                                  tint: Theme.accent) {
                        run { await model.reopen(item) }
                    }
                }
            case .completed:
                ThemedMenuRow(icon: "arrow.uturn.backward", title: "撤销完成", tint: Theme.accent) {
                    run { await model.toggleCompletion(item) }
                }
            case .abandoned:
                ThemedMenuRow(icon: "arrow.uturn.backward", title: "恢复", tint: Theme.accent) {
                    run { await model.toggleCompletion(item) }
                }
            }
        }
    }

    // MARK: 快捷改期

    private var rescheduleSection: some View {
        let task = item.task
        let today = model.today
        let current: LocalDate? = task.undated ? nil : item.occurrence.startDate
        let all = [DateChoice(id: "今天", day: today),
                   DateChoice(id: "明天", day: today.adding(days: 1)),
                   DateChoice(id: "下周一", day: Self.nextMonday(after: today))]
        let choices = all.filter { $0.day != current }
        let canClear = !task.isRepeating && !task.undated
        let taskID = task.id1
        return VStack(alignment: .leading, spacing: 6) {
            ThemedMenuCaption(task.isRepeating ? "改期（只改这一次）" : "改期")
            HStack(spacing: 6) {
                ForEach(choices) { choice in
                    ThemedMenuChip(title: choice.id, tint: Theme.accent) {
                        moveDate(to: choice.day)
                    }
                }
                if canClear {
                    ThemedMenuChip(title: "无日期", tint: Theme.subtext) {
                        run { await model.clearSchedule(taskID) }
                    }
                }
            }
        }
    }

    // MARK: 待办单

    private var listSection: some View {
        let lists = model.snapshot.lists
        let current = item.task.id3
        return VStack(alignment: .leading, spacing: 8) {
            ThemedMenuCaption("移到分类")
            ThemedMenuGroup {
                if lists.count > 5 {
                    ScrollView { listRows(lists, current: current) }
                        .frame(height: 170)
                } else {
                    listRows(lists, current: current)
                }
                ThemedMenuSeparator()
                ThemedMenuRow(icon: "plus", title: "新建分类…", tint: Theme.accent) {
                    close()
                    afterMenuCloses { model.listEditor = ListEditorRequest(list: nil) }
                }
            }
        }
    }

    private func listRows(_ lists: [TodoList], current: String) -> some View {
        let taskID = item.task.id1
        return VStack(spacing: 0) {
            ForEach(lists) { list in
                ThemedMenuListRow(color: list.swatch, title: list.displayName, selected: list.id3 == current) {
                    run { await model.moveTask(taskID, to: list.id3) }
                }
            }
        }
    }

    // MARK: 底部图标栏

    private var toolbar: some View {
        let task = item.task
        let target = item
        return HStack(spacing: 0) {
            ThemedMenuIconButton(icon: task.collected ? "star.slash" : "star",
                                 title: task.collected ? "取消收藏" : "收藏", tint: Theme.accent) {
                run { await model.updateTask(task.id1, collected: !task.collected) }
            }
            ThemedMenuIconButton(icon: "repeat", title: task.isRepeating ? "重复规则" : "设为重复",
                                 tint: Quadrant.notImportantUrgent.tint) {
                close()
                afterMenuCloses { model.recurrenceRequest = task }
            }
            ThemedMenuIconButton(icon: "doc.on.doc", title: "复制标题", tint: Theme.subtext) {
                close()
                Platform.copy(task.taskTitle)
            }
            ThemedMenuIconButton(icon: "trash", title: "删除", tint: Theme.overdue, destructive: true) {
                close()
                afterMenuCloses { model.deleteRequest = target }
            }
        }
        .themedCard()
    }
}

private struct DateChoice: Identifiable {
    let id: String
    let day: LocalDate
}

// MARK: - 侧栏待办单的菜单面板

struct ListContextMenu: View {
    @Environment(AppModel.self) private var model
    let list: TodoList
    let close: () -> Void

    var body: some View {
        let count = model.counts.perList[list.id3] ?? 0
        ThemedMenuPanel(title: list.displayName, subtitle: "\(count) 条待完成", tint: list.swatch) {
            ThemedMenuGroup {
                ThemedMenuRow(icon: "plus", title: "在此新建任务", tint: Theme.accent) {
                    close()
                    afterMenuCloses {
                        var preset = NewTaskPreset()
                        preset.listID = list.id3
                        preset.date = model.today
                        model.newTaskPreset = preset
                    }
                }
            }
            if list.isDefault {
                ThemedMenuCaption("「未分类」不能改名或删除")
            } else {
                ThemedMenuGroup {
                    ThemedMenuRow(icon: "pencil", title: "编辑名称和颜色…", tint: Quadrant.notImportantUrgent.tint) {
                        close()
                        afterMenuCloses { model.listEditor = ListEditorRequest(list: list) }
                    }
                }
                ThemedMenuGroup {
                    ThemedMenuRow(icon: "trash", title: "删除分类…", tint: Theme.overdue, destructive: true) {
                        close()
                        afterMenuCloses { model.listDeleteRequest = list }
                    }
                }
            }
        }
    }
}
