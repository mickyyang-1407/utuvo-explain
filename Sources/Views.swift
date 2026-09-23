import AppKit
import SwiftUI

struct MainView: View {
    @Bindable var model: AppModel
    let onSettings: () -> Void
    let onPermission: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("UTUVO Explain")
                        .font(.headline)
                    Text("貓貓翻譯家")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .frame(width: 28, height: 28)
                        .background(.quaternary.opacity(0.4), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("設定 Gemini API Key 與提示詞")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("原文")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !model.sourceText.isEmpty && !model.isEditingSource {
                        Button("編輯") { model.isEditingSource = true }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
                if model.isEditingSource {
                    TextEditor(text: $model.sourceText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(height: 58)
                } else if model.sourceText.isEmpty {
                    HStack(spacing: 4) {
                        Text("選取文字後按快捷鍵，")
                            .foregroundStyle(.secondary)
                        Button("或在這裡貼上") { model.isEditingSource = true }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                    }
                    .font(.subheadline)
                } else {
                    Text(model.sourceText)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                modeButton(.explain, shortcut: "⌥D")
                modeButton(.translate, shortcut: "⌥⇧D")
            }
            .disabled(model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(model.mode.rawValue)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if !model.resultText.isEmpty {
                        Button {
                            model.copyResult()
                        } label: {
                            Label("複製", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                ScrollView {
                    Text(model.resultText.isEmpty ? (model.isLoading ? "Gemini 正在處理…" : "結果會顯示在這裡") : model.resultText)
                        .foregroundStyle(model.resultText.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary.opacity(0.6)))

            HStack(spacing: 8) {
                if model.isLoading { ProgressView().controlSize(.small) }
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(model.statusText == "完成" ? .secondary : .primary)
                    .lineLimit(2)
                Spacer()
                if !model.hasAccessibility {
                    Button("開啟系統設定", action: onPermission)
                        .font(.caption)
                } else if !model.hasKey {
                    Button("設定 Key", action: onSettings)
                        .font(.caption)
                }
            }
        }
        .padding(16)
        .frame(width: 420, height: 400)
    }

    private func modeButton(_ mode: ExplainMode, shortcut: String) -> some View {
        Button {
            model.mode = mode
            model.run()
        } label: {
            HStack {
                Text(mode.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                Text(shortcut)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .frame(maxWidth: .infinity)
            .background(model.mode == mode ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(model.mode == mode ? Color.accentColor.opacity(0.65) : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView: View {
    let model: AppModel
    @State private var keyDraft = ""
    @State private var modelDraft: String
    @State private var explainDraft: String
    @State private var translateDraft: String
    @State private var message = ""
    @State private var showAdvanced = false

    init(model: AppModel) {
        self.model = model
        _modelDraft = State(initialValue: AppSettings.model)
        _explainDraft = State(initialValue: AppSettings.prompt(for: .explain))
        _translateDraft = State(initialValue: AppSettings.prompt(for: .translate))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("設定").font(.title2.bold())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Gemini API Key").font(.headline)
                    Text(model.hasKey ? "Key 已存在 Mac 鑰匙圈。需要更換時才重新貼上。" : "點下方連結 → 建立 API Key → 複製貼上。請選 Free Tier 專案。")
                        .font(.caption).foregroundStyle(.secondary)
                    SecureField("貼上 API Key", text: $keyDraft)
                        .textFieldStyle(.roundedBorder)
                    Link("開啟 Google AI Studio", destination: URL(string: "https://aistudio.google.com/api-keys")!)
                    Text("只有你按快捷鍵或功能按鈕時，文字才會送往 Gemini。免費層級的內容可能被 Google 用於改進產品。")
                        .font(.caption).foregroundStyle(.secondary)
                }

                DisclosureGroup("進階設定：模型與提示詞", isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 15) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("模型").font(.headline)
                            TextField("模型名稱", text: $modelDraft)
                                .textFieldStyle(.roundedBorder)
                            Text("預設：gemini-3.5-flash-lite").font(.caption).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("白話解釋提示詞").font(.headline)
                            TextEditor(text: $explainDraft)
                                .font(.body).frame(height: 105)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("翻譯提示詞").font(.headline)
                            TextEditor(text: $translateDraft)
                                .font(.body).frame(height: 105)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                        }
                    }
                    .padding(.top, 10)
                }

                HStack {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("儲存設定") { save() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(22)
        }
        .frame(width: 510, height: 380)
    }

    private func save() {
        let modelName = modelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelName.isEmpty else {
            message = "模型名稱不能留空。"
            return
        }
        do {
            let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { try KeychainStore.save(key) }
            UserDefaults.standard.set(modelName, forKey: AppSettings.modelKey)
            UserDefaults.standard.set(explainDraft, forKey: AppSettings.explainPromptKey)
            UserDefaults.standard.set(translateDraft, forKey: AppSettings.translatePromptKey)
            keyDraft = ""
            model.refreshKeyStatus()
            message = "已儲存。現在可以選字按 ⌥D。"
        } catch {
            message = error.localizedDescription
        }
    }
}
