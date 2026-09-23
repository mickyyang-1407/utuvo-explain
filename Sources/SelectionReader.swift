import ApplicationServices
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
        guard !trimmed.isEmpty else { return .noSelection }
        let focusedElement = element as! AXUIElement
        return .text(Selection(text: trimmed, bounds: selectedTextBounds(in: focusedElement)))
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
