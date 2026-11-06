// 拾页：菜单栏小工具。把网页拖到图标上保存，点条目在 Safari 打开，点条目右侧的 × 删除（移到删除历史）。
// 「设置…」里可以看地址、改名称，以及恢复删除过的网页。
import AppKit
import ServiceManagement
import SwiftUI

/// 列表里的一行：点标题在 Safari 打开并收起菜单；悬停时右侧出现 ×，点 × 只删这一行，菜单不收起。
final class LinkRowView: NSView {
    var onOpen: () -> Void = {}
    var onRemove: () -> Void = {}

    private let name: String
    private let label = NSTextField(labelWithString: "")
    private let removeButton = NSButton()

    init(name: String, url: String) {
        self.name = name
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        autoresizingMask = [.width]
        toolTip = url

        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        removeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "删除")
        removeButton.isBordered = false
        removeButton.imagePosition = .imageOnly
        removeButton.toolTip = "删除"
        removeButton.target = self
        removeButton.action = #selector(remove)
        removeButton.isHidden = true
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        addSubview(removeButton)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: removeButton.leadingAnchor, constant: -6),
            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    // 菜单高亮某一行时会把它重画，在这里切换高亮底色、文字颜色和 × 的显示。
    override func draw(_ dirtyRect: NSRect) {
        let highlighted = enclosingMenuItem?.isHighlighted ?? false
        if highlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0), xRadius: 5, yRadius: 5).fill()
        }
        removeButton.isHidden = !highlighted
        removeButton.contentTintColor = highlighted ? .selectedMenuItemTextColor : nil

        label.attributedStringValue = NSAttributedString(string: name, attributes: [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: highlighted ? NSColor.selectedMenuItemTextColor : NSColor.labelColor,
        ])
    }

    override func mouseUp(with event: NSEvent) {
        enclosingMenuItem?.menu?.cancelTracking()
        onOpen()
    }

    @objc private func remove() {
        onRemove()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, NSDraggingDestination {
    private let store = Store()
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let contextMenu = NSMenu()
    private let loginItem = NSMenuItem(title: "登录时启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let icon = "bookmark"
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(icon)
        menu.delegate = self
        loginItem.target = self
        contextMenu.addItem(loginItem)
        contextMenu.addItem(.separator())
        contextMenu.addItem(withTitle: "退出拾页", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        // 左键弹出网页列表，右键弹出开机启动和退出。
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        // 图标所在的窗口接收拖放，窗口把拖放消息转给它的 delegate。
        if let window = statusItem.button?.window {
            window.registerForDraggedTypes([.URL, .string])
            window.delegate = self
        }
    }

    // MARK: 拖放

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        link(from: sender.draggingPasteboard) == nil ? [] : .copy
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let (url, title) = link(from: sender.draggingPasteboard) else { return false }
        store.add(url: url, title: title.isEmpty ? safariTabTitle(for: url) : title)
        flashSaved()
        return true
    }

    /// 从拖进来的内容里取地址和标题；只认 http、https 和本地文件地址。
    private func link(from pasteboard: NSPasteboard) -> (String, String)? {
        let raw = (NSURL(from: pasteboard) as URL?)?.absoluteString
            ?? pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, let url = URL(string: raw), ["http", "https", "file"].contains(url.scheme?.lowercased() ?? "") else {
            return nil
        }
        var title = pasteboard.string(forType: NSPasteboard.PasteboardType("public.url-name")) ?? ""
        // Safari 拖链接时把标题放在 [[地址], [标题]] 这个旧格式里。
        if title.isEmpty,
           let pair = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("WebURLsWithTitlesPboardType")) as? [[String]],
           pair.count == 2, let first = pair[1].first {
            title = first
        }
        return (url.absoluteString, title.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// 从地址栏拖出来时不带标题，就到 Safari 已打开的标签页里按地址找。找不到返回空。
    private func safariTabTitle(for url: String) -> String {
        let quoted = url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let result = runSafariScript("""
        tell application "Safari"
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t is "\(quoted)" then return name of t
                end repeat
            end repeat
        end tell
        return ""
        """)
        return result?.stringValue ?? ""
    }

    // MARK: 菜单

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if store.links.isEmpty {
            let hint = NSMenuItem(title: "把网页地址拖到菜单栏图标上即可保存", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        }
        for link in store.links {
            let item = NSMenuItem()
            let row = LinkRowView(name: link.displayName, url: link.url)
            row.onOpen = { [weak self] in self?.open(link.url) }
            row.onRemove = { [weak self, weak menu, weak item] in
                self?.store.remove(url: link.url)
                if let item { menu?.removeItem(item) }
            }
            item.view = row
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",").target = self
    }

    // MARK: 动作

    /// 临时挂上菜单再点一下按钮，菜单就会以系统样式弹在图标下方，弹完再摘掉，以便区分左右键。
    @objc private func statusItemClicked() {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        statusItem.menu = NSApp.currentEvent?.type == .rightMouseUp ? contextMenu : menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store)))
            window.title = "拾页"
            window.setContentSize(NSSize(width: 580, height: 440))
            window.isReleasedWhenClosed = false
            // 每次打开都出现在当前桌面，全屏和分屏的桌面里也能显示，不会跳回原来的桌面。
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func open(_ string: String) {
        guard let url = URL(string: string),
              let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") else { return }
        NSWorkspace.shared.open([url], withApplicationAt: safari, configuration: NSWorkspace.OpenConfiguration())
    }

    /// 运行控制 Safari 的脚本；出错时弹窗说明，并返回 nil。
    private func runSafariScript(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int
            alert(code == -1743
                  ? "没有控制 Safari 的权限。请到「系统设置 → 隐私与安全性 → 自动化」里，允许「拾页」控制 Safari。"
                  : "读取 Safari 网页失败：\(error[NSAppleScript.errorMessage] ?? "未知错误")")
            return nil
        }
        return result
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            alert("设置登录时启动失败：\(error.localizedDescription)")
        }
    }

    // MARK: 辅助

    private func setIcon(_ symbol: String) {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "拾页")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    /// 保存成功后图标短暂变成对勾。
    private func flashSaved() {
        setIcon("checkmark")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            self.setIcon(self.icon)
        }
    }

    private func alert(_ message: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "拾页"
        alert.informativeText = message
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
