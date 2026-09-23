import AppKit
import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

enum SelectionReader {
    struct Selection {
        let text: String
        let bounds: CGRect?
    }

    enum Result {
        case text(Selection)
        case noSelection
        case permissionNeeded
    }

    static func read(allowCopyFallback: Bool) async -> Result {
        guard AXIsProcessTrusted() else { return .permissionNeeded }
        let system = AXUIElementCreateSystemWide()
        _ = AXUIElementSetMessagingTimeout(system, 0.5)
        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
           let element = focused {
            let focusedElement = element as! AXUIElement
            var selected: CFTypeRef?
            if AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selected) == .success,
               let text = selected as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return .text(Selection(text: trimmed, bounds: selectedTextBounds(in: focusedElement)))
                }
            }
        }
        if allowCopyFallback, let text = await copySelectedText() {
            return .text(Selection(text: text, bounds: nil))
        }
        return .noSelection
    }

    private static func copySelectedText() async -> String? {
        let pasteboard = NSPasteboard.general
        guard let savedItems = snapshot(pasteboard) else { return nil }
        let targetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // Wait for the shortcut modifiers to be released before sending Copy.
        for _ in 0..<25 {
            let flags = CGEventSource.flagsState(.hidSystemState)
            if !flags.contains(.maskAlternate) && !flags.contains(.maskShift)
                && !flags.contains(.maskCommand) && !flags.contains(.maskControl) { break }
            try? await Task.sleep(for: .milliseconds(40))
        }
        guard !Task.isCancelled else { return nil }
        let flags = CGEventSource.flagsState(.hidSystemState)
        guard !flags.contains(.maskAlternate) && !flags.contains(.maskShift)
            && !flags.contains(.maskCommand) && !flags.contains(.maskControl) else { return nil }

        let originalChange = pasteboard.changeCount
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false) else { return nil }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)

        for _ in 0..<12 {
            if pasteboard.changeCount != originalChange { break }
            try? await Task.sleep(for: .milliseconds(30))
        }
        guard pasteboard.changeCount != originalChange else { return nil }
        let copiedChange = pasteboard.changeCount
        let copiedText = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if pasteboard.changeCount == copiedChange {
            pasteboard.clearContents()
            if !savedItems.isEmpty { _ = pasteboard.writeObjects(savedItems) }
        }
        guard !Task.isCancelled,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID,
              let copiedText, !copiedText.isEmpty else { return nil }
        return copiedText
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem]? {
        var savedItems: [NSPasteboardItem] = []
        var byteCount = 0
        for item in pasteboard.pasteboardItems ?? [] {
            let saved = NSPasteboardItem()
            for type in item.types {
                guard let data = item.data(forType: type) else { return nil }
                byteCount += data.count
                guard byteCount <= 32 * 1_024 * 1_024,
                      saved.setData(data, forType: type) else { return nil }
            }
            savedItems.append(saved)
        }
        return savedItems
    }

    private static func selectedTextBounds(in element: AXUIElement) -> CGRect? {
        var selectedRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &selectedRange
        ) == .success,
              let rangeObject = selectedRange,
              CFGetTypeID(rangeObject) == AXValueGetTypeID() else { return nil }
        let rangeValue = rangeObject as! AXValue
        guard AXValueGetType(rangeValue) == .cfRange else { return nil }

        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range), range.length > 0 else { return nil }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue, &boundsValue
        ) == .success,
              let rectangleObject = boundsValue,
              CFGetTypeID(rectangleObject) == AXValueGetTypeID() else { return nil }
        let rectangleValue = rectangleObject as! AXValue
        guard AXValueGetType(rectangleValue) == .cgRect else { return nil }

        var bounds = CGRect.zero
        guard AXValueGetValue(rectangleValue, .cgRect, &bounds),
              bounds.width > 0, bounds.height > 0,
              bounds.origin.x.isFinite, bounds.origin.y.isFinite else { return nil }
        return bounds
    }
}
