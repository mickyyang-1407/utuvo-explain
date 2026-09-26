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
    private var tutorialWindow: NSWindow?
    private var hotKeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var tapUpgradeTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        ScreenTextReader.prewarm()
        if !installEventTap() {
            registerHotKeys()
            if !AXIsProcessTrusted() {
                model.statusText = "請在系統設定的「裝置控制和資料取用」開啟 UTUVO Explain。"
            }
            startTapUpgrade()
        }
        if TutorialState.shouldShowOnLaunch {
            showTutorial()
        } else {
            showPanel()
        }
    }

    private func setupMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.make()
        item.button?.toolTip = "UTUVO Explain・貓貓翻譯家"
        let menu = NSMenu()
        let title = NSMenuItem(title: "UTUVO Explain・貓貓翻譯家", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        let open = NSMenuItem(title: "開啟視窗", action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let settings = NSMenuItem(title: "設定…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        let tutorial = NSMenuItem(title: "使用教學…", action: #selector(openTutorial), keyEquivalent: "")
        tutorial.target = self
        menu.addItem(tutorial)
        let capture = NSMenuItem(title: "框選螢幕文字…", action: #selector(captureScreen), keyEquivalent: "")
        capture.target = self
        menu.addItem(capture)
        let shortcuts = NSMenuItem(title: "白話解釋 ⌥D  ·  翻譯 ⌥⇧D", action: nil, keyEquivalent: "")
        shortcuts.isEnabled = false
        menu.addItem(shortcuts)
        let screenShortcuts = NSMenuItem(title: "框選螢幕：解釋 ⌥S  ·  翻譯 ⌥⇧S", action: nil, keyEquivalent: "")
        screenShortcuts.isEnabled = false
        menu.addItem(screenShortcuts)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "結束 UTUVO Explain", action: #selector(quitApp), keyEquivalent: "")
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
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                guard type == .keyDown,
                      keyCode == Int64(kVK_ANSI_D) || keyCode == Int64(kVK_ANSI_S) else {
                    return Unmanaged.passUnretained(event)
                }
                let flags = event.flags
                guard flags.contains(.maskAlternate),
                      !flags.contains(.maskCommand),
                      !flags.contains(.maskControl) else {
                    return Unmanaged.passUnretained(event)
                }
                // One physical press can produce repeat events after the panel takes focus.
                // Consume those events without running a second selection lookup.
                if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
                    return nil
                }
                let shiftDown = flags.contains(.maskShift)
                    || CGEventSource.flagsState(.hidSystemState).contains(.maskShift)
                    || CGEventSource.flagsState(.combinedSessionState).contains(.maskShift)
                    || CGEventSource.keyState(.hidSystemState, key: CGKeyCode(kVK_Shift))
                    || CGEventSource.keyState(.hidSystemState, key: CGKeyCode(kVK_RightShift))
                let fromScreen = keyCode == Int64(kVK_ANSI_S)
                _ = MainActor.assumeIsolated {
                    Task { [weak owner] in
                        let mode: ExplainMode = shiftDown ? .translate : .explain
                        if fromScreen {
                            owner?.handleScreenHotKey(mode)
                        } else {
                            owner?.handleHotKey(mode)
                        }
                    }
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
        model.statusText = "準備就緒"
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
            MainActor.assumeIsolated {
                let mode: ExplainMode = hotKeyID.id % 2 == 0 ? .translate : .explain
                if hotKeyID.id >= 3 {
                    owner.handleScreenHotKey(mode)
                } else {
                    owner.handleHotKey(mode)
                }
            }
            return noErr
        }
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &type, pointer, &handler)
        var registrationResults: [String] = []
        // 1 ⌥D, 2 ⌥⇧D (selection); 3 ⌥S, 4 ⌥⇧S (screen region OCR).
        let bindings: [(UInt32, Int, UInt32)] = [
            (1, kVK_ANSI_D, UInt32(optionKey)), (2, kVK_ANSI_D, UInt32(optionKey | shiftKey)),
            (3, kVK_ANSI_S, UInt32(optionKey)), (4, kVK_ANSI_S, UInt32(optionKey | shiftKey)),
        ]
        for (id, keyCode, modifiers) in bindings {
            var reference: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(0x4D455850), id: id)
            let status = RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &reference)
            registrationResults.append("\(id):\(status)")
            if status == noErr,
               let reference {
                hotKeys.append(reference)
            }
        }
        if handlerStatus != noErr || hotKeys.count != bindings.count {
            model.statusText = "快捷鍵無法啟用（\(handlerStatus), \(registrationResults.joined(separator: ", "))）。請先用手動輸入。"
        }
    }

    private var selectionTask: Task<Void, Never>?

    private func handleHotKey(_ mode: ExplainMode) {
        let isAppFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
        selectionTask?.cancel()
        model.beginSelection(mode: mode)
        selectionTask = Task { [weak self] in
            guard let self else { return }
            let selection = await SelectionReader.read(allowCopyFallback: !isAppFrontmost)
            guard !Task.isCancelled else { return }
            switch selection {
            case .text(let selection):
                self.showPanel(near: selection.bounds)
                self.model.prepare(selection.text, mode: mode)
            case .noSelection:
                self.showPanel()
                if isAppFrontmost && !self.model.sourceText.isEmpty {
                    // The panel owns focus after the first shortcut. Reuse its text when
                    // the user switches modes with a second shortcut.
                    self.model.prepare(self.model.sourceText, mode: mode)
                } else {
                    self.model.showNoSelection(mode: mode)
                }
            case .permissionNeeded:
                self.showPanel()
                self.model.statusText = "請按「開啟系統設定」，允許 UTUVO Explain 後再重試。"
            }
        }
    }

    private var isCapturingScreen = false
    private var panelPlaced = false

    private func handleScreenHotKey(_ mode: ExplainMode) {
        // Only the framing step is exclusive: a second press while the system
        // picker is open would stack a second picker. During recognition a new
        // press starts over and the older result is dropped.
        guard !isCapturingScreen else { return }
        guard ScreenTextReader.hasPermission else {
            // Nothing to frame yet: keep the panel where it is and explain why.
            ScreenTextReader.requestPermission()
            model.needsScreenRecording = true
            showPanel(keepPosition: true)
            model.endScreenCapture(status: "框選螢幕需要「螢幕與系統錄音」權限；開啟後重新啟動 App。")
            return
        }
        selectionTask?.cancel()
        isCapturingScreen = true
        let panelWasVisible = panel?.isVisible == true
        // Keep the panel out of the picture the user is about to frame.
        panel?.orderOut(nil)
        model.beginScreenCapture(mode: mode)
        selectionTask = Task { [weak self] in
            let result = await ScreenTextReader.captureAndRecognize(onCaptured: { [weak self] in
                guard let self else { return }
                self.isCapturingScreen = false
                // Show progress right away; recognition can take a few seconds.
                self.showPanel(keepPosition: panelWasVisible)
                self.model.beginRecognizing()
            })
            guard let self else { return }
            self.isCapturingScreen = false
            guard !Task.isCancelled else { return }
            // Return the panel to where it was instead of chasing the mouse.
            switch result {
            case .text(let text):
                self.showPanel(keepPosition: panelWasVisible)
                self.model.prepare(text, mode: mode)
            case .cancelled:
                self.model.endScreenCapture(status: "已取消框選。")
                if panelWasVisible { self.showPanel(keepPosition: true) }
            case .noText:
                self.showPanel(keepPosition: panelWasVisible)
                self.model.endScreenCapture(status: "框選範圍裡沒有辨識到文字，請框大一點再試。")
            case .permissionNeeded:
                self.model.needsScreenRecording = true
                self.showPanel(keepPosition: panelWasVisible)
                self.model.endScreenCapture(status: "框選螢幕需要「螢幕與系統錄音」權限；開啟後重新啟動 App。")
            case .failed(let message):
                self.showPanel(keepPosition: panelWasVisible)
                self.model.endScreenCapture(status: message)
            }
        }
    }

    private func requestScreenRecording() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        if let url { NSWorkspace.shared.open(url) }
    }

    private func showPanel(near selectionBounds: CGRect? = nil, keepPosition: Bool = false) {
        if panel == nil {
            let window = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
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
                onPermission: { [weak self] in self?.requestAccessibility() },
                onCapture: { [weak self] in self?.handleScreenHotKey(self?.model.mode ?? .explain) },
                onScreenPermission: { [weak self] in self?.requestScreenRecording() }
            ))
            panel = window
        }
        if let panel, !(keepPosition && panelPlaced) {
            panelPlaced = true
            if let selectionBounds,
               let (anchor, screen) = appKitBounds(for: selectionBounds) {
                panel.setFrameOrigin(panelOrigin(near: anchor, on: screen, size: panel.frame.size))
            } else if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
                let x = min(NSEvent.mouseLocation.x + 18, screen.visibleFrame.maxX - panel.frame.width)
                let y = max(NSEvent.mouseLocation.y - panel.frame.height - 12, screen.visibleFrame.minY)
                panel.setFrameOrigin(NSPoint(x: max(x, screen.visibleFrame.minX), y: y))
            }
        }
        // After the system picker closes, macOS may refuse to activate this app;
        // the panel still has to appear.
        panel?.orderFrontRegardless()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func appKitBounds(for accessibilityBounds: CGRect) -> (CGRect, NSScreen)? {
        let selectionCenter = CGPoint(x: accessibilityBounds.midX, y: accessibilityBounds.midY)
        for screen in NSScreen.screens {
            guard let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            let displayBounds = CGDisplayBounds(CGDirectDisplayID(displayNumber.uint32Value))
            guard displayBounds.contains(selectionCenter),
                  displayBounds.width > 0, displayBounds.height > 0 else { continue }
            let scaleX = screen.frame.width / displayBounds.width
            let scaleY = screen.frame.height / displayBounds.height
            let localX = (accessibilityBounds.minX - displayBounds.minX) * scaleX
            let localY = (accessibilityBounds.minY - displayBounds.minY) * scaleY
            let bounds = CGRect(
                x: screen.frame.minX + localX,
                y: screen.frame.maxY - localY - accessibilityBounds.height * scaleY,
                width: accessibilityBounds.width * scaleX,
                height: accessibilityBounds.height * scaleY
            )
            return (bounds, screen)
        }
        return nil
    }

    private func panelOrigin(near anchor: CGRect, on screen: NSScreen, size: CGSize) -> NSPoint {
        let visible = screen.visibleFrame
        let gap: CGFloat = 12
        let x = min(max(anchor.minX, visible.minX), visible.maxX - size.width)
        let below = anchor.minY - gap - size.height
        let above = anchor.maxY + gap
        let y: CGFloat
        if below >= visible.minY {
            y = below
        } else if above + size.height <= visible.maxY {
            y = above
        } else {
            y = min(max(below, visible.minY), visible.maxY - size.height)
        }
        return NSPoint(x: x, y: y)
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

    private func showTutorial() {
        if tutorialWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "UTUVO Explain 使用教學"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: TutorialView(
                onSettings: { [weak self] in self?.showSettings() },
                onScreenPermission: { [weak self] in
                    ScreenTextReader.requestPermission()
                    self?.requestScreenRecording()
                },
                onFinish: { [weak self] in self?.tutorialWindow?.close() }
            ))
            window.center()
            tutorialWindow = window
        }
        tutorialWindow?.makeKeyAndOrderFront(nil)
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
        guard let closedWindow = notification.object as? NSWindow else { return }
        if closedWindow === tutorialWindow {
            TutorialState.markSeen()
            showPanel()
        } else if closedWindow === settingsWindow, tutorialWindow?.isVisible != true {
            showPanel()
        }
    }

    @objc private func openPanel() { showPanel() }
    @objc private func openTutorial() { showTutorial() }
    @objc private func captureScreen() { handleScreenHotKey(.explain) }
    @objc private func openSettings() { showSettings() }
    @objc private func quitApp() { NSApp.terminate(nil) }
}
