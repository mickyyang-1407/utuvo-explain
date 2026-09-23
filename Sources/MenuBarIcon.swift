import AppKit

@MainActor enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            let outline = NSColor(srgbRed: 0.27, green: 0.23, blue: 0.34, alpha: 1)
            let fur = NSColor(srgbRed: 0.96, green: 0.68, blue: 0.43, alpha: 1)
            let ear = NSColor(srgbRed: 0.99, green: 0.77, blue: 0.75, alpha: 1)
            let book = NSColor(srgbRed: 0.43, green: 0.34, blue: 0.77, alpha: 1)
            let page = NSColor(srgbRed: 0.96, green: 0.94, blue: 1, alpha: 1)

            func draw(_ path: NSBezierPath, fill: NSColor, stroke: NSColor = outline, width: CGFloat = 0.7) {
                fill.setFill()
                path.fill()
                stroke.setStroke()
                path.lineWidth = width
                path.lineJoinStyle = .round
                path.stroke()
            }

            let ears = NSBezierPath()
            ears.move(to: NSPoint(x: 2.7, y: 12.2))
            ears.line(to: NSPoint(x: 2.8, y: 18.1))
            ears.line(to: NSPoint(x: 6.9, y: 15.7))
            ears.move(to: NSPoint(x: 10.3, y: 15.7))
            ears.line(to: NSPoint(x: 14.4, y: 18.1))
            ears.line(to: NSPoint(x: 14.5, y: 12.2))
            draw(ears, fill: fur)

            let innerEars = NSBezierPath()
            innerEars.move(to: NSPoint(x: 3.8, y: 16.3))
            innerEars.line(to: NSPoint(x: 4.0, y: 14.1))
            innerEars.line(to: NSPoint(x: 5.6, y: 15.4))
            innerEars.move(to: NSPoint(x: 11.6, y: 15.4))
            innerEars.line(to: NSPoint(x: 13.2, y: 14.1))
            innerEars.line(to: NSPoint(x: 13.4, y: 16.3))
            ear.setStroke()
            innerEars.lineWidth = 1.5
            innerEars.stroke()

            draw(NSBezierPath(ovalIn: NSRect(x: 2.6, y: 6.7, width: 12, height: 9.6)), fill: fur)
            outline.setFill()
            NSBezierPath(ovalIn: NSRect(x: 6.0, y: 11.3, width: 1.0, height: 1.35)).fill()
            NSBezierPath(ovalIn: NSRect(x: 10.2, y: 11.3, width: 1.0, height: 1.35)).fill()
            draw(NSBezierPath(ovalIn: NSRect(x: 8.0, y: 9.4, width: 1.3, height: 0.9)), fill: ear, width: 0.35)

            let leftPage = NSBezierPath()
            leftPage.move(to: NSPoint(x: 3.8, y: 8.8))
            leftPage.curve(to: NSPoint(x: 11.0, y: 7.9), controlPoint1: NSPoint(x: 6.3, y: 9.5), controlPoint2: NSPoint(x: 8.7, y: 9.1))
            leftPage.line(to: NSPoint(x: 11.0, y: 1.9))
            leftPage.curve(to: NSPoint(x: 3.8, y: 2.9), controlPoint1: NSPoint(x: 8.6, y: 3.2), controlPoint2: NSPoint(x: 6.1, y: 3.5))
            leftPage.close()
            draw(leftPage, fill: page, stroke: book, width: 1.1)

            let rightPage = NSBezierPath()
            rightPage.move(to: NSPoint(x: 11.0, y: 7.9))
            rightPage.curve(to: NSPoint(x: 18.2, y: 8.8), controlPoint1: NSPoint(x: 13.4, y: 9.1), controlPoint2: NSPoint(x: 15.8, y: 9.5))
            rightPage.line(to: NSPoint(x: 18.2, y: 2.9))
            rightPage.curve(to: NSPoint(x: 11.0, y: 1.9), controlPoint1: NSPoint(x: 15.8, y: 3.5), controlPoint2: NSPoint(x: 13.3, y: 3.2))
            rightPage.close()
            draw(rightPage, fill: page, stroke: book, width: 1.1)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "UTUVO Explain・貓咪讀書"
        return image
    }
}
