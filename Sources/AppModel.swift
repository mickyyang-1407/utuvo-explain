import AppKit
import Foundation
import Observation

@MainActor @Observable final class AppModel {
    var sourceText = ""
    var resultText = ""
    var statusText = "選取文字後按 ⌥D，就能看白話解釋。"
    var mode: ExplainMode = .explain
    var isLoading = false
    var hasKey = KeychainStore.read() != nil

    @ObservationIgnored private var currentTask: Task<Void, Never>?

    func prepare(_ text: String, mode: ExplainMode) {
        self.mode = mode
        sourceText = text
        resultText = ""
        run()
    }

    func run() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusText = "先選取文字，或在上方貼上文字。"
            return
        }
        guard text.count <= 6_000 else {
            statusText = "文字太長，請選取較短的一段（最多 6,000 字）。"
            return
        }
        guard let key = KeychainStore.read(), !key.isEmpty else {
            hasKey = false
            statusText = "先到設定貼上 Gemini API Key。"
            return
        }
        currentTask?.cancel()
        resultText = ""
        isLoading = true
        statusText = "正在送給 Gemini…"
        let currentMode = mode
        currentTask = Task {
            do {
                let answer = try await GeminiClient().generate(text: text, mode: currentMode, key: key)
                guard !Task.isCancelled else { return }
                resultText = answer
                statusText = "完成"
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                statusText = error.localizedDescription
            }
            isLoading = false
        }
    }

    func copyResult() {
        guard !resultText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resultText, forType: .string)
        statusText = "已複製結果"
    }

    func refreshKeyStatus() {
        hasKey = KeychainStore.read() != nil
    }
}
