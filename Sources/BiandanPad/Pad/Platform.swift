import CoreGraphics
import Foundation

#if os(iOS)
import AudioToolbox
import UIKit
#else
import AppKit
#endif

/// macOS 专有系统能力在 iPadOS 上的等价实现。
///
/// 上游 macOS 版直接调用 `NSWorkspace` / `NSPasteboard` / `NSSound` 等 AppKit 接口，
/// 移植时统一收口到这里，界面和业务代码只调 `Platform.xxx`，两端的差异只留在本文件。
enum Platform {
    /// 用系统浏览器打开链接（macOS 是 NSWorkspace.shared.open）。
    static func open(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    /// 在访达 / 文件 App 里显示导出的文件。
    static func reveal(_ url: URL) {
        #if os(iOS)
        // iOS 没有访达，导出后由界面弹分享面板，这里不做额外动作。
        _ = url
        #else
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }

    /// 复制文本到剪贴板。
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    /// 把 App 切到前台（iOS 上系统自己会切，不需要处理）。
    static func activate() {
        #if os(macOS)
        NSApp.activate(ignoringOtherApps: true)
        #endif
    }

    /// 番茄钟结束提示音：macOS 播系统的 Glass，iPadOS 播系统提示音。
    static func playDoneSound() {
        #if os(iOS)
        AudioServicesPlaySystemSound(1057)
        #else
        NSSound(named: NSSound.Name("Glass"))?.play()
        #endif
    }

    /// CGColor 换算成 sRGB 分量。系统日历给的颜色是 CGColor，两端的颜色类型不同。
    struct SRGB {
        var redComponent: Double
        var greenComponent: Double
        var blueComponent: Double
    }

    static func sRGB(_ color: CGColor?) -> SRGB? {
        guard let color else { return nil }
        #if os(iOS)
        let ui = UIColor(cgColor: color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return SRGB(redComponent: Double(r), greenComponent: Double(g), blueComponent: Double(b))
        #else
        guard let rgb = NSColor(cgColor: color)?.usingColorSpace(.sRGB) else { return nil }
        return SRGB(redComponent: Double(rgb.redComponent), greenComponent: Double(rgb.greenComponent),
                    blueComponent: Double(rgb.blueComponent))
        #endif
    }
}

/// 硬件键盘的修饰键状态。触屏设备没有全局修饰键，多选改由「选择」模式承担。
enum HardwareKeys {
    static var shiftDown: Bool {
        #if os(iOS)
        return false
        #else
        return NSEvent.modifierFlags.contains(.shift)
        #endif
    }

    static var commandDown: Bool {
        #if os(iOS)
        return false
        #else
        return NSEvent.modifierFlags.contains(.command)
        #endif
    }

    /// 让窗口接管键盘焦点（iOS 由系统管理第一响应者，无需处理）。
    static func resignTextFocus() {
        #if os(macOS)
        if let window = NSApp.keyWindow, !(window.firstResponder is NSWindow) {
            window.makeFirstResponder(nil)
        }
        #endif
    }
}

/// iPad 端需要界面配合的系统动作（分享面板、文件选择器）。
/// 业务层只投通知，视图在根部统一接管，避免把 UIKit 的弹窗逻辑塞进 AppModel。
enum PadSystemUI {
    /// 导出文件已写好，携带文件 URL。
    static let exportReady = Notification.Name("biandan.pad.exportReady")
    /// 请求弹出 .ics 文件选择器。
    static let pickImportFile = Notification.Name("biandan.pad.pickImportFile")
}


extension PadSystemUI {
    /// 请求打开设置面板（iPad 用弹层，没有独立的设置窗口）。
    static let openSettings = Notification.Name("biandan.pad.openSettings")
}
