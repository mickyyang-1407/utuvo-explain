import AppKit
import ApplicationServices
import Foundation
import Observation

@MainActor @Observable final class AppModel {
    var sourceText = ""
    var resultText = ""
    var statusText = "選取文字後按 ⌥D；圖片或影片裡的字按 ⌥S 框選。"
    var mode: ExplainMode = .explain
    var isLoading = false
    var isEditingSource = false
    var hasKey = KeychainStore.read() != nil
    var hasAccessibility = AXIsProcessTrusted()
    var needsScreenRecording = false

    @ObservationIgnored private var currentTask: Task<Void, Never>?

    func prepare(_ text: String, mode: ExplainMode) {
        self.mode = mode
        needsScreenRecording = false
        sourceText = text
        resultText = ""
        isEditingSource = false
        run()
    }

    func beginSelection(mode: ExplainMode) {
        currentTask?.cancel()
        self.mode = mode
        resultText = ""
        isLoading = false
        statusText = "正在讀取選字…"
    }

    func beginScreenCapture(mode: ExplainMode) {
        currentTask?.cancel()
        self.mode = mode
        isLoading = false
        statusText = "拖曳框選要辨識的範圍；按空白鍵可改選視窗，Esc 取消。"
    }

    func beginRecognizing() {
        sourceText = ""
        resultText = ""
        isEditingSource = false
        isLoading = true
        statusText = "正在辨識框選範圍裡的文字…"
    }

    func endScreenCapture(status: String) {
        isLoading = false
        statusText = status
    }

    func showNoSelection(mode: ExplainMode) {
        currentTask?.cancel()
        self.mode = mode
        sourceText = ""
        resultText = ""
        isLoading = false
        isEditingSource = false
        statusText = "讀不到選取文字；請複製文字後貼到上方原文欄。"
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
        isEditingSource = false
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
            } catch let error as URLError where error.code == .timedOut {
                guard !Task.isCancelled else { return }
                statusText = "Gemini 太久沒回應，請再按一次；文字很長時可以框小一點。"
            } catch let error as URLError where error.code == .notConnectedToInternet {
                guard !Task.isCancelled else { return }
                statusText = "目前沒有網路，連上後再按一次。"
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

    func refreshAccessibilityStatus() {
        hasAccessibility = AXIsProcessTrusted()
    }
}
