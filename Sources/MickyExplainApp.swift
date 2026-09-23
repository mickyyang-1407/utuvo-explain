import AppKit
import ApplicationServices
import Carbon
import SwiftUI

@main struct MickyExplainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var settingsWindow: NSWindow?
    private var hotKeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        registerHotKeys()
        showPanel()
    }

    private func setupMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "text.book.closed", accessibilityDescription: "Micky Explain")
        let menu = NSMenu()
        let open = NSMenuItem(title: "開啟 Micky Explain", action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let settings = NSMenuItem(title: "設定…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "結束", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    private func registerHotKeys() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let owner = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { owner.handleHotKey(hotKeyID.id) }
            return noErr
        }
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &type, pointer, &handler)
        var registrationResults: [String] = []
        for (id, modifiers) in [(UInt32(1), UInt32(optionKey)), (UInt32(2), UInt32(optionKey | shiftKey))] {
            var reference: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(0x4D455850), id: id)
            let status = RegisterEventHotKey(UInt32(kVK_ANSI_D), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &reference)
            registrationResults.append("\(id):\(status)")
            if status == noErr,
               let reference {
                hotKeys.append(reference)
            }
        }
        if handlerStatus != noErr || hotKeys.count != 2 {
            model.statusText = "快捷鍵無法啟用（\(handlerStatus), \(registrationResults.joined(separator: ", "))）。請先用手動輸入。"
        }
    }

    private func handleHotKey(_ id: UInt32) {
        let mode: ExplainMode = id == 2 ? .translate : .explain
        switch SelectionReader.read() {
        case .text(let selected):
            showPanel()
            model.prepare(selected, mode: mode)
        case .noSelection:
            showPanel()
            model.mode = mode
            model.statusText = "沒有讀到選取文字；可以在原文欄貼上後按「開始」。"
        case .permissionNeeded:
            showPanel()
            model.statusText = "請先允許 Micky Explain 使用「輔助使用」，再重試。"
            SelectionReader.requestPermission()
        }
    }

    private func showPanel() {
        if panel == nil {
            let window = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 485),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Micky Explain"
            window.isFloatingPanel = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: MainView(model: model, onSettings: { [weak self] in self?.showSettings() }))
            panel = window
        }
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }),
           let panel {
            let x = min(NSEvent.mouseLocation.x + 18, screen.visibleFrame.maxX - panel.frame.width)
            let y = max(NSEvent.mouseLocation.y - panel.frame.height - 12, screen.visibleFrame.minY)
            panel.setFrameOrigin(NSPoint(x: max(x, screen.visibleFrame.minX), y: y))
        }
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 510, height: 565),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Micky Explain 設定"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openPanel() { showPanel() }
    @objc private func openSettings() { showSettings() }
    @objc private func quitApp() { NSApp.terminate(nil) }
}
