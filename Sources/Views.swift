import AppKit
import SwiftUI

struct MainView: View {
    @Bindable var model: AppModel
    let onSettings: () -> Void
    let onPermission: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "text.book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text("UTUVO Explain").font(.headline)
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                }
                .help("設定 Gemini API Key 與提示詞")
            }

            if model.isEditingSource {
                TextEditor(text: $model.sourceText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 75)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            } else if model.sourceText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("選取文字，按 ⌥D")
                        .font(.title3.weight(.semibold))
                    Text("想直接翻譯，就按 ⌥⇧D。")
                        .foregroundStyle(.secondary)
                    Button("或在這裡貼上文字") { model.isEditingSource = true }
                }
                .frame(maxWidth: .infinity, minHeight: 75, alignment: .leading)
            } else {
                HStack(alignment: .top) {
                    Text(model.sourceText)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("編輯") { model.isEditingSource = true }
                        .font(.caption)
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 75, alignment: .topLeading)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 8) {
                Button("白話解釋") {
                    model.mode = .explain
                    model.run()
                }
                .buttonStyle(.borderedProminent)
                Button("翻譯") {
                    model.mode = .translate
                    model.run()
                }
                .buttonStyle(.bordered)
                Spacer()
                if !model.resultText.isEmpty {
                    Button("複製結果") { model.copyResult() }
                }
            }
            .disabled(model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Divider()

            ScrollView {
                Text(model.resultText.isEmpty ? (model.isLoading ? "Gemini 正在處理…" : "結果會顯示在這裡") : model.resultText)
                    .foregroundStyle(model.resultText.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
        .frame(width: 420, height: 360)
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
