import AppKit
import ApplicationServices
import Carbon
import CoreGraphics
import SwiftUI

@main struct UTUVOExplainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var settingsWindow: NSWindow?
    private var hotKeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var tapUpgradeTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        if !installEventTap() {
            registerHotKeys()
            if !AXIsProcessTrusted() {
                model.statusText = "請在系統設定的「裝置控制和資料取用」開啟 UTUVO Explain。"
            }
            startTapUpgrade()
        }
        showPanel()
    }

    private func setupMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "text.book.closed", accessibilityDescription: "UTUVO Explain")
        let menu = NSMenu()
        let open = NSMenuItem(title: "開啟 UTUVO Explain", action: #selector(openPanel), keyEquivalent: "")
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

    private func installEventTap() -> Bool {
        guard eventTap == nil, AXIsProcessTrusted() else { return false }
        model.hasAccessibility = true
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userData in
                guard let userData else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    MainActor.assumeIsolated {
                        if let tap = owner.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                    }
                    return Unmanaged.passUnretained(event)
                }
                guard type == .keyDown,
                      event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_ANSI_D) else {
                    return Unmanaged.passUnretained(event)
                }
                let flags = event.flags
                guard flags.contains(.maskAlternate),
                      !flags.contains(.maskCommand),
                      !flags.contains(.maskControl) else {
                    return Unmanaged.passUnretained(event)
                }
                MainActor.assumeIsolated {
                    owner.handleHotKey(flags.contains(.maskShift) ? .translate : .explain)
                }
                return nil
            },
            userInfo: pointer
        ) else {
            model.statusText = "快捷鍵尚未就緒。請確認系統權限，並重新開啟 App。"
            return false
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        eventTapSource = source
        model.statusText = "快捷鍵已就緒：⌥D 解釋，⌥⇧D 翻譯。"
        return true
    }

    private func startTapUpgrade() {
        tapUpgradeTask = Task { [weak self] in
            while let self, self.eventTap == nil {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self.model.refreshAccessibilityStatus()
                if self.installEventTap() {
                    self.unregisterHotKeys()
                    return
                }
            }
        }
    }

    private func unregisterHotKeys() {
        for key in hotKeys { UnregisterEventHotKey(key) }
        hotKeys.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    private func registerHotKeys() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let owner = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { owner.handleHotKey(hotKeyID.id == 2 ? .translate : .explain) }
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

    private func handleHotKey(_ mode: ExplainMode) {
        switch SelectionReader.read() {
        case .text(let selected):
            showPanel()
            model.prepare(selected, mode: mode)
        case .noSelection:
            showPanel()
            model.mode = mode
            model.statusText = "沒有讀到選取文字；可以貼上文字後按「白話解釋」或「翻譯」。"
        case .permissionNeeded:
            showPanel()
            model.statusText = "請按「開啟系統設定」，允許 UTUVO Explain 後再重試。"
        }
    }

    private func showPanel() {
        if panel == nil {
            let window = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "UTUVO Explain"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isFloatingPanel = true
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: MainView(
                model: model,
                onSettings: { [weak self] in self?.showSettings() },
                onPermission: { [weak self] in self?.requestAccessibility() }
            ))
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
                contentRect: NSRect(x: 0, y: 0, width: 510, height: 380),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "UTUVO Explain 設定"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func requestAccessibility() {
        guard let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            model.statusText = "請在系統設定的「裝置控制和資料取用」開啟 UTUVO Explain。"
            return
        }
        let opened = NSWorkspace.shared.open(settingsURL)
        model.refreshAccessibilityStatus()
        model.statusText = opened
            ? "在「裝置控制和資料取用」開啟 UTUVO Explain，回來後就能按 ⌥D。"
            : "請在系統設定的「裝置控制和資料取用」開啟 UTUVO Explain。"
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow,
              closedWindow === settingsWindow else { return }
        showPanel()
    }

    @objc private func openPanel() { showPanel() }
    @objc private func openSettings() { showSettings() }
    @objc private func quitApp() { NSApp.terminate(nil) }
}
