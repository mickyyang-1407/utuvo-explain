import AppKit
import SwiftUI

/// First-launch walkthrough, also reachable from the menu bar (使用教學…).
struct TutorialView: View {
    let onSettings: () -> Void
    let onScreenPermission: () -> Void
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let eyebrow: String
        let title: String
        let lines: [String]
        let image: String?
    }

    private let pages: [Page] = [
        Page(eyebrow: "開始之前", title: "三步就能用",
             lines: ["① 到設定貼上自己的 Gemini API Key（免費申請）。",
                     "② 第一次按快捷鍵時，允許「裝置控制和資料取用」。",
                     "③ 之後在任何 App 選字、或框選螢幕，按快捷鍵就好。"],
             image: nil),
        Page(eyebrow: "⌥D ・ ⌥⇧D", title: "選字，按快捷鍵",
             lines: ["在瀏覽器、PDF、郵件裡選取一段文字。",
                     "按 ⌥D 看白話解釋；按 ⌥⇧D 只要譯文。",
                     "某個 App 抓不到選字時，把文字貼進視窗的原文欄也可以。"],
             image: "TutorialExplain"),
        Page(eyebrow: "⌥S ・ ⌥⇧S", title: "圖片、影片裡的字，框起來",
             lines: ["按 ⌥S 會出現十字指標，拖曳框住字幕或圖片裡的字。",
                     "按空白鍵可以改選整個視窗，按 Esc 取消。",
                     "按 ⌥⇧S 框完直接翻譯。"],
             image: "TutorialFrame"),
        Page(eyebrow: "結果", title: "框完，小視窗馬上出現",
             lines: ["先顯示「正在辨識」，接著出現解釋或譯文。",
                     "文字辨識在 Mac 本機完成，只把辨識出的字送給 Gemini；截圖用完就刪。",
                     "有錯字可以按「編輯」修正，再按一次解釋或翻譯。",
                     "第一次用 ⌥S，macOS 會請你允許「螢幕與系統錄音」，開啟後重新啟動 App。"],
             image: "TutorialTranslate"),
    ]

    var body: some View {
        let current = pages[page]
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                    .resizable().interpolation(.high)
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                Text("UTUVO Explain 使用教學").font(.headline)
                Spacer()
                Text("\(page + 1) / \(pages.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Group {
                if let name = current.image {
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel(current.title)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                        .resizable().interpolation(.high)
                        .frame(width: 150, height: 150)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 280)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(current.eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(current.title).font(.title2.bold())
                ForEach(current.lines, id: \.self) { line in
                    Text(line)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if page == 0 {
                    Button("開啟設定", action: onSettings)
                } else if page == pages.count - 1 {
                    Button("開啟螢幕錄製設定", action: onScreenPermission)
                }
                Spacer()
                if page > 0 {
                    Button("上一步") { page -= 1 }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                }
                if page < pages.count - 1 {
                    Button("下一步") { page += 1 }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("開始使用", action: onFinish)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(22)
        .frame(width: 560, height: 620)
    }
}

enum TutorialState {
    /// Bumped when the tutorial gains a feature worth showing to existing users.
    static let seenKey = "tutorialSeenVersion"
    static let currentVersion = 2

    static var shouldShowOnLaunch: Bool {
        UserDefaults.standard.integer(forKey: seenKey) < currentVersion
    }

    static func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: seenKey)
    }
}
