import AppKit
import CoreGraphics
import CoreText
import Foundation
import Vision

/// Reads text from a screen region the user drags out. The region picker is the
/// system `screencapture -i` UI; recognition runs locally with Vision. Only the
/// recognized text leaves this file — the image is deleted right after OCR.
enum ScreenTextReader {
    enum Result: Equatable {
        case text(String)
        case cancelled
        case noText
        case permissionNeeded
        case failed(String)
    }

    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// Registers the app in System Settings and shows the system prompt once.
    static func requestPermission() { _ = CGRequestScreenCaptureAccess() }

    /// `onCaptured` runs as soon as the user finishes framing, before recognition,
    /// so the caller can show progress instead of an empty screen.
    static func captureAndRecognize(onCaptured: () -> Void = {}) async -> Result {
        guard hasPermission else {
            requestPermission()
            return .permissionNeeded
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("utuvo-explain-ocr-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            try await runInteractiveCapture(to: url)
        } catch {
            return .failed("無法開始框選：\(error.localizedDescription)")
        }
        // Esc or a click without dragging leaves no file.
        guard FileManager.default.fileExists(atPath: url.path) else { return .cancelled }
        onCaptured()
        return await recognize(fileAt: url)
    }

    /// Vision waits on the Neural Engine with no deadline, and `VNRequest.cancel()`
    /// does not interrupt that wait. A busy engine must not leave the panel on
    /// "recognizing" forever, so the caller gets a timeout result and a late
    /// recognition is ignored.
    nonisolated static func recognize(fileAt url: URL, timeout: TimeInterval = 20) async -> Result {
        await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                once.resume(recognizeNow(fileAt: url))
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                once.resume(.failed("辨識模型還在準備（第一次使用會比較久），請稍後再框選一次。"))
            }
        }
    }

    /// The first recognition in a freshly installed app waits for the Neural Engine
    /// to compile Vision's models. Doing that at launch keeps the user's first ⌥S fast.
    nonisolated static func prewarm() {
        DispatchQueue.global(qos: .utility).async {
            let width = 240, height = 64
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let font = CTFontCreateWithName("Helvetica" as CFString, 28, nil)
            let text = NSAttributedString(string: "Explain 文字", attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
            ])
            context.textPosition = CGPoint(x: 12, y: 20)
            CTLineDraw(CTLineCreateWithAttributedString(text), context)
            guard let image = context.makeImage() else { return }
            _ = try? recognizeText(in: image)
        }
    }

    nonisolated static func recognizeNow(fileAt url: URL) -> Result {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return .failed("讀不到框選的畫面。")
        }
        do {
            let text = try recognizeText(in: image)
            return text.isEmpty ? .noText : .text(text)
        } catch {
            return .failed("文字辨識失敗：\(error.localizedDescription)")
        }
    }

    /// Top-to-bottom, left-to-right lines joined with newlines.
    nonisolated static func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.recognitionLanguages = ["zh-Hant", "en-US", "ja-JP", "ko-KR", "zh-Hans"]
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let lines = (request.results ?? [])
            .compactMap { observation -> (CGRect, String)? in
                guard let text = observation.topCandidates(1).first?.string
                    .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
                return (observation.boundingBox, text)
            }
            .sorted { a, b in
                // Vision's origin is bottom-left. Same line when vertical centers are close.
                let tolerance = min(a.0.height, b.0.height) / 2
                if abs(a.0.midY - b.0.midY) > tolerance { return a.0.midY > b.0.midY }
                return a.0.minX < b.0.minX
            }
            .map(\.1)
        return lines.joined(separator: "\n")
    }

    private static func runInteractiveCapture(to url: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i interactive region (Space toggles window mode), -x no sound, -o no window shadow.
        process.arguments = ["-i", "-x", "-o", url.path]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in continuation.resume() }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Resumes a continuation with whichever result arrives first.
nonisolated private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ScreenTextReader.Result, Never>?
    init(_ continuation: CheckedContinuation<ScreenTextReader.Result, Never>) {
        self.continuation = continuation
    }
    func resume(_ result: ScreenTextReader.Result) {
        let pending = lock.withLock { () -> CheckedContinuation<ScreenTextReader.Result, Never>? in
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(returning: result)
    }
}
