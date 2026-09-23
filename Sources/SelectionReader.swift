import ApplicationServices
import Foundation

enum SelectionReader {
    enum Result {
        case text(String)
        case noSelection
        case permissionNeeded
    }

    static func read() -> Result {
        guard AXIsProcessTrusted() else { return .permissionNeeded }
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return .noSelection }
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String else { return .noSelection }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .noSelection : .text(trimmed)
    }
}
