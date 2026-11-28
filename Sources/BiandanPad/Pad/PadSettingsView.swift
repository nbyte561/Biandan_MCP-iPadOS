import SwiftUI

/// iPad 上的设置面板。
///
/// macOS 版是一个独立的设置窗口（左侧分区栏 + 右侧内容）；iPadOS 用一张弹层承载同样的分区，
/// 视觉仍按 DESIGN.md：米色背景、白卡片、黄色强调，不用系统灰底分组。
struct PadSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private enum Pane: String, CaseIterable, Identifiable {
        case account, sync, reminder, data, mcp, about
        var id: String { rawValue }

        var title: String {
            switch self {
            case .account: return "账户"
            case .sync: return "同步"
            case .reminder: return "提醒"
            case .data: return "数据"
            case .mcp: return "MCP"
            case .about: return "关于"
            }
        }

        var icon: String {
            switch self {
            case .account: return "person.crop.circle"
            case .sync: return "arrow.triangle.2.circlepath"
            case .reminder: return "bell.badge"
            case .data: return "square.and.arrow.up"
            case .mcp: return "point.3.connected.trianglepath.dotted"
            case .about: return "info.circle"
            }
        }

        var tint: Color {
            switch self {
            case .account: return Quadrant.importantUrgent.tint
            case .sync: return Quadrant.notImportantUrgent.tint
            case .reminder: return Quadrant.importantNotUrgent.tint
            case .data: return Quadrant.neither.tint
            case .mcp: return Theme.purple
            case .about: return Theme.subtext
            }
        }
    }

    @State private var pane: Pane = .account
    @AppStorage(PadAppearance.defaultsKey) private var appearance = PadAppearance.system.rawValue

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                sidebar
                Divider().overlay(Theme.line)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        paneHeader
                        switch pane {
                        case .account: accountPane
                        case .sync: syncPane
                        case .reminder: reminderPane
                        case .data: dataPane
                        case .mcp: mcpPane
                        case .about: aboutPane
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Theme.background)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.panel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - 外壳

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Pane.allCases) { item in
                let on = item == pane
                Button {
                    pane = item
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: item.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6).fill(item.tint))
                        Text(item.title)
                            .font(.system(size: 13, weight: on ? .bold : .medium))
                            .foregroundStyle(Theme.text)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(on ? Theme.card : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(on ? Theme.line : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 186)
        .background(Theme.panel)
    }

    private var paneHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: pane.icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(pane.tint))
            Text(pane.title)
                .font(.system(size: 22, weight: .heavy))
            Spacer(minLength: 0)
        }
    }

    // MARK: - 账户

    private var accountPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            InspectorSection("账号") {
                ThemedRow("名称") { Text(model.profile.displayName) }
                ThemedRow("登录状态") {
                    Text(model.demoMode ? "示例模式（不连云端）"
                                        : (model.authState == .signedIn ? "已登录" : "未登录"))
                        .foregroundStyle(model.authState == .signedIn ? Theme.done : Theme.subtext)
                }
            }
            InspectorSection("续期") {
                if let renewal = model.renewal {
                    ThemedRow("下次续期") {
                        Text(renewal.nextRenewalAt.map { Self.dateText($0) } ?? "—")
                    }
                    ThemedRow("需要重新登录") {
                        Text(renewal.reloginBy.map { Self.dayText($0) } ?? "—")
                            .foregroundStyle(Theme.subtext)
                    }
                } else {
                    note("登录后显示续期状态")
                }
            }
            if model.demoMode {
                Button("退出示例模式") {
                    model.exitDemoMode()
                    dismiss()
                }
                .buttonStyle(.themedDestructive)
            } else {
                Button("退出登录") {
                    model.signOutRequested = true
                }
                .buttonStyle(.themedDestructive)
            }
        }
    }

    // MARK: - 同步

    private var syncPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            InspectorSection("自动同步") {
                ThemedRow("间隔") {
                    ThemedSegmented(selection: Binding(get: { model.syncIntervalMinutes },
                                                       set: { model.syncIntervalMinutes = $0 }),
                                    options: [1, 5, 15, 30].map { ThemeOption(value: $0, title: "\($0) 分") })
                }
                ThemedRow("上次同步") {
                    Text(model.lastSyncedAt.map { Self.dateText($0) } ?? "尚未同步")
                }
                ThemedRow("状态") {
                    Text(syncText).foregroundStyle(syncColor)
                }
            }
            InspectorSection("待同步队列") {
                if model.outboxEntries.isEmpty {
                    note("没有排队的修改")
                } else {
                    ForEach(model.outboxEntries, id: \.opID) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.payload?.label ?? entry.command)
                                .font(.system(size: 12.5, weight: .semibold))
                            Text("\(entry.state == OutboxEntry.failed ? "已放弃" : "待同步") · 尝试 \(entry.attempts) 次"
                                 + (entry.lastError.map { " · \($0)" } ?? ""))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.subtext)
                                .lineLimit(2)
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                Button("立即同步") { Task { await model.syncNow(.manual) } }
                    .buttonStyle(.themed)
                    .disabled(model.syncStatus.isSyncing)
                if !model.outboxEntries.isEmpty {
                    Button("重放队列") { Task { await model.flushOutbox() } }
                        .buttonStyle(.themed)
                }
            }
        }
    }

    private var syncText: String {
        switch model.syncStatus {
        case .idle: return model.authState == .signedIn ? "空闲" : "未登录"
        case .syncing(let message): return message
        case .failed(let message): return message
        }
    }

    private var syncColor: Color {
        if case .failed = model.syncStatus { return Theme.overdue }
        return Theme.subtext
    }

    // MARK: - 提醒

    private var reminderPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            InspectorSection("时间提醒") {
                HStack(spacing: 10) {
                    Text("到点提醒").font(.system(size: 13))
                    Spacer(minLength: 0)
                    ThemedSwitch(isOn: Binding(get: { model.remindersEnabled },
                                               set: { model.remindersEnabled = $0 }))
                }
                ThemedRow("系统授权") {
                    Text(reminderStatusText).foregroundStyle(Theme.subtext)
                }
                ThemedRow("已排提醒") {
                    Text("\(model.scheduledReminderCount) 条")
                }
            }
            Button("检查系统授权") { Task { await model.refreshReminderStatus() } }
                .buttonStyle(.themed)
            note("iPad 上提醒由系统通知中心投递；点通知里的「完成」会直接写回云端。")
        }
    }

    private var reminderStatusText: String {
        switch model.reminderStatus {
        case .authorized: return "已允许"
        case .denied: return "未允许（去系统设置里开启）"
        case .notDetermined: return "还没询问"
        case .unavailable: return "当前环境不支持通知"
        case .silenced: return "已允许，但提醒样式为「无」"
        }
    }

    // MARK: - 数据

    private var dataPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            InspectorSection("导出") {
                ForEach(ExportFormat.allCases) { format in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(format.title).font(.system(size: 13, weight: .semibold))
                            Text(format.detail).font(.system(size: 11)).foregroundStyle(Theme.subtext)
                        }
                        Spacer(minLength: 0)
                        Button("导出") { model.exportData(format) }
                            .buttonStyle(.themed)
                    }
                }
            }
            InspectorSection("本机备份") {
                ThemedRow("最近一次") {
                    Text(model.lastBackupAt.map { Self.dateText($0) } ?? "还没有自动备份")
                }
                Button("立即备份") { Task { await model.backupNow() } }
                    .buttonStyle(.themed)
            }
            if let notice = model.exportNotice {
                ThemedErrorText(message: notice)
            }
        }
    }

    // MARK: - MCP

    private var mcpPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            InspectorSection("本机 MCP 服务") {
                HStack(spacing: 10) {
                    Text("开启").font(.system(size: 13))
                    Spacer(minLength: 0)
                    ThemedSwitch(isOn: Binding(get: { model.mcpEnabled }, set: { model.mcpEnabled = $0 }))
                }
                ThemedRow("状态") {
                    Text(mcpStatusText).foregroundStyle(Theme.subtext)
                }
                ThemedRow("调用次数") { Text("\(model.mcpCallCount)") }
            }
            if let key = model.mcpAccessKey {
                InspectorSection("访问密钥") {
                    Text(key)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                    Button("拷贝客户端配置") {
                        _ = model.copyMCPConfig()
                    }
                    .buttonStyle(.themed)
                }
            }
            note("iPad 上的 MCP 服务只在 App 位于前台时监听；把配置里的地址换成这台 iPad 的局域网 IP，"
                 + "同一 Wi-Fi 下的电脑就能连上来读写待办。")
            if let notice = model.mcpNotice {
                ThemedErrorText(message: notice)
            }
        }
    }

    private var mcpStatusText: String { model.mcpStatus.title }

    // MARK: - 关于

    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                BrandLogo(size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("便单 for iPadOS")
                        .font(.system(size: 18, weight: .heavy))
                    Text("四象限待办，和鸿蒙手机、平板、Mac 同步")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subtext)
                }
            }
            InspectorSection("外观") {
                ThemedRow("主题") {
                    ThemedSegmented(selection: $appearance,
                                    options: PadAppearance.allCases.map { ThemeOption(value: $0.rawValue, title: $0.title) })
                }
                note("默认跟随 iPad 的「显示与亮度」。深色下沿用同一套暖色调，不会换成系统灰。")
            }
            InspectorSection("说明") {
                note("这个版本是把 macOS 客户端（BiandanMac）移植到 iPadOS 的实验版本："
                     + "业务层（云端同步、重复规则、离线队列、MCP）与界面组件沿用同一份代码，"
                     + "只替换了窗口外壳、登录用的浏览器和 macOS 专有能力。", color: Theme.text)
            }
            InspectorSection("数据") {
                ThemedRow("分类") { Text("\(model.snapshot.lists.count)") }
                ThemedRow("任务") { Text("\(model.snapshot.tasks.count)") }
                ThemedRow("执行实例") { Text("\(model.snapshot.occurrences.count)") }
                ThemedRow("专注记录") { Text("\(model.snapshot.focus.count)") }
            }
        }
    }

    /// 卡片里的一段说明文字：和 ThemedRow 同样的内边距，不会被卡片圆角切掉。
    private func note(_ text: String, color: Color = Theme.subtext) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    // MARK: - 格式化

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private static func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}
