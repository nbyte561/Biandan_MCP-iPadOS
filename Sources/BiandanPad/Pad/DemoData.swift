import Foundation

/// 演示数据。
///
/// iPad 版在没有华为账号的环境里（比如第一次装、或者在模拟器里看界面）也能看到真实界面，
/// 所以提供一个按钮，把几条示例任务按云端的记录格式写进本机数据库 —— 走的完全是
/// `LocalStore.apply` 那条同步落库路径，不绕过任何业务逻辑，也不碰云端。
/// 示例数据模式：带 BIANDAN_PAD_DEMO=1 启动时打开，只在本机库里放示例任务，不联网、不读钥匙串。
enum DemoFlags {
    /// 截图/排查用：带 BIANDAN_PAD_DEMO=1 启动。
    static var enabled: Bool {
        ProcessInfo.processInfo.environment["BIANDAN_PAD_DEMO"] == "1"
    }

    /// 用户在登录页点过「先随便看看」，之后每次启动都算示例模式。
    static func enter() { UserDefaults.standard.set(true, forKey: DemoData.defaultsKey) }
    static func clear() { UserDefaults.standard.removeObject(forKey: DemoData.defaultsKey) }
}

@MainActor
enum DemoData {
    /// 记住「用户在示例模式里」这件事，下次启动直接进主界面。
    static let defaultsKey = "biandan.pad.demoMode"

    /// 清掉示例模式标记（示例数据仍留在本机库，不会被删）。
    static func clearMode() {
        DemoFlags.clear()
    }

    /// 库为空时写一份示例数据（已经写过就什么都不做）。
    static func seedIfEmpty(into model: AppModel) {
        guard model.snapshot.tasks.isEmpty else { return }
        seed(into: model)
    }

    static func seed(into model: AppModel) {
        let today = LocalDate.today()
        var tasks: [RawRecord] = []
        var occurrences: [RawRecord] = []
        var lists: [RawRecord] = []
        var focus: [RawRecord] = []

        // 三个分类：未分类是云端固定存在的 id3=1。
        let listDefs: [(String, String, Int64)] = [("1", "未分类", 0), ("2", "工作", 3), ("3", "生活", 6)]
        for (index, def) in listDefs.enumerated() {
            lists.append(record(.favorites, cloudID: "demo-list-\(def.0)", attributes: [
                "id3": .string(def.0),
                "favoritesName": .string(def.1),
                "favoritesColor": .int(def.2),
            ], order: index))
        }

        /// 一条任务的完整描述。quadrant 用 重要性/紧急性 两个开关表示，与云端字段一致。
        struct Seed {
            let title: String
            let content: String
            let list: String
            let important: Int64
            let urgent: Int64
            let dayOffset: Int?
            let start: String?
            let end: String?
            let collected: Bool
            let repeatKind: Int64
            let completed: Bool
        }

        let seeds: [Seed] = [
            Seed(title: "整理这周的评审意见", content: "把评审里的问题按模块归类\n- 交互 3 条\n- 文案 5 条", list: "2",
                 important: 1, urgent: 1, dayOffset: 0, start: "10:00:00", end: "11:00:00",
                 collected: true, repeatKind: 0, completed: false),
            Seed(title: "和腾讯对齐接口联调时间", content: "后天下午 3 点，线上会议", list: "2",
                 important: 1, urgent: 1, dayOffset: 0, start: "15:00:00", end: "16:00:00",
                 collected: false, repeatKind: 0, completed: false),
            Seed(title: "写 iPad 版迁移说明", content: "", list: "2",
                 important: 1, urgent: 0, dayOffset: 1, start: "09:30:00", end: "12:00:00",
                 collected: false, repeatKind: 0, completed: false),
            Seed(title: "看一遍四象限的用法", content: "", list: "1",
                 important: 1, urgent: 0, dayOffset: nil, start: nil, end: nil,
                 collected: false, repeatKind: 0, completed: false),
            Seed(title: "回运营的排期确认", content: "", list: "2",
                 important: 0, urgent: 1, dayOffset: 0, start: "18:00:00", end: "18:30:00",
                 collected: false, repeatKind: 0, completed: false),
            Seed(title: "买牛奶和咖啡豆", content: "", list: "3",
                 important: 0, urgent: 0, dayOffset: 2, start: nil, end: nil,
                 collected: false, repeatKind: 0, completed: false),
            Seed(title: "每天读 20 页书", content: "", list: "3",
                 important: 1, urgent: 0, dayOffset: 0, start: nil, end: nil,
                 collected: false, repeatKind: 2, completed: false),
            Seed(title: "整理下载文件夹", content: "", list: "1",
                 important: 0, urgent: 0, dayOffset: nil, start: nil, end: nil,
                 collected: false, repeatKind: 0, completed: false),
            Seed(title: "把上周的复盘发到群里", content: "", list: "2",
                 important: 1, urgent: 1, dayOffset: -1, start: nil, end: nil,
                 collected: false, repeatKind: 0, completed: true),
            Seed(title: "预约体检", content: "", list: "3",
                 important: 0, urgent: 1, dayOffset: -2, start: nil, end: nil,
                 collected: false, repeatKind: 0, completed: true),
        ]

        for (index, seed) in seeds.enumerated() {
            let id1 = "\(1000 + index)"
            let id2 = "\(2000 + index)"
            let day = seed.dayOffset.map { today.adding(days: $0) }
            var attributes: JSONObject = [
                "id1": .string(id1),
                "taskTitle": .string(seed.title),
                "taskContent": .string(seed.content),
                "id3": .string(seed.list),
                "isImportant": .int(seed.important),
                "isUrgency": .int(seed.urgent),
                "isCollectible": .int(seed.collected ? 1 : 0),
                "isLoop": .int(seed.repeatKind),
                "haveNoTime": .int(day == nil ? 1 : 0),
                "unitTimeNumber": .int(1),
                "validStartTime": .string(seed.start ?? "00:00:00"),
                "validEndTime": .string(seed.end ?? "23:59:59"),
                "isRemind": .int(seed.start == nil ? 0 : 1),
                "isFinish": .int(seed.completed ? 1 : 0),
                "loopSet": .int(0),
                "loopBaseNumber": .int(1),
                "loopUnit": .int(0),
                "duration": .int(0),
                "latitude": .double(-1),
                "longitude": .double(-1),
                "location": .string(""),
            ]
            if let day {
                attributes["startTime"] = .string(day.iso)
                attributes["endTime"] = .string(day.iso)
            }
            if seed.repeatKind >= 2 {
                // 每天重复：与云端 loopSet/isLoop 的组合一致。
                attributes["loopSet"] = .int(2)
                attributes["loopBaseNumber"] = .int(1)
                attributes["loopUnit"] = .int(1)
            }
            if seed.start != nil, let day {
                attributes["remindDate"] = .string(day.iso)
                attributes["remindTime"] = .string(seed.start ?? "09:00:00")
            }
            tasks.append(record(.task, cloudID: "demo-task-\(id1)", attributes: attributes, order: index))

            // 执行实例：无日期任务也有一条，与云端一致。
            var occAttributes: JSONObject = [
                "id2": .string(id2),
                "id1": .string(id1),
                "validStartTime": .string(seed.start ?? "00:00:00"),
                "validEndTime": .string(seed.end ?? "23:59:59"),
                "completedCount": .int(seed.completed ? 1 : 0),
                "isFinish": .int(seed.completed ? 1 : 0),
                "recentFinishedTime": .string(seed.completed ? "\(day?.iso ?? today.iso) 18:00:00" : ""),
            ]
            if let day {
                occAttributes["startTime"] = .string(day.iso)
                occAttributes["endTime"] = .string(day.iso)
            }
            occurrences.append(record(.showTask, cloudID: "demo-occ-\(id2)", attributes: occAttributes, order: index))
        }

        // 几条专注记录，让「专注记录」和「统计」页有内容。
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        for offset in 0..<6 {
            let day = today.adding(days: -offset)
            let ms = now - Int64(offset) * 86_400_000
            focus.append(record(.tomato, cloudID: "demo-focus-\(offset)", attributes: [
                "time": .string("\(ms)"),
                "date": .string(day.iso),
                "goodCount": .int(Int64(2 + offset % 3)),
                "badCount": .int(Int64(offset % 2)),
                "minutes": .double(Double(50 + offset * 10)),
                "log": .string("{\"title\":\"写代码\",\"detail\":\"迁移 iPad 界面\"}"),
            ], order: offset))
        }

        do {
            _ = try model.store.apply([.favorites: lists, .task: tasks, .showTask: occurrences, .tomato: focus])
            model.reloadSnapshot()
            // 进示例模式：不登录也能看完整界面，重启后仍然有效。
            DemoFlags.enter()
            model.demoMode = true
            model.profile = AccountProfile(displayName: "示例数据", avatarURL: nil)
            model.authState = .signedIn
        } catch {
            model.lastError = "写入示例数据失败：\(error.localizedDescription)"
        }
    }

    private static func record(_ kind: RecordKind, cloudID: String, attributes: JSONObject, order: Int) -> RawRecord {
        RawRecord(kind: kind,
                  cloudID: cloudID,
                  version: 1,
                  createdTime: "2026-11-01T09:00:00.000Z",
                  editedTime: "2026-11-20T09:00:0\(order % 10).000Z",
                  attributes: attributes)
    }
}
