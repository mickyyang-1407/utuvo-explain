import AppKit
import SwiftUI

struct MainView: View {
    @Bindable var model: AppModel
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "text.book.closed.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Micky Explain").font(.headline)
                    Text("選字，一鍵看懂").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                }
                .help("設定 Gemini API Key 與提示詞")
            }

            Picker("功能", selection: $model.mode) {
                ForEach(ExplainMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 6) {
                Text("原文").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $model.sourceText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 90, maxHeight: 120)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Text("⌥D 解釋  ·  ⌥⇧D 翻譯")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("開始") { model.run() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
            }

            Divider()

            HStack {
                Text(model.mode.rawValue).font(.headline)
                Spacer()
                if !model.resultText.isEmpty {
                    Button("複製") { model.copyResult() }
                }
            }
            ScrollView {
                Text(model.resultText.isEmpty ? (model.isLoading ? "正在思考…" : "結果會顯示在這裡") : model.resultText)
                    .foregroundStyle(model.resultText.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 105)

            HStack(spacing: 8) {
                if model.isLoading { ProgressView().controlSize(.small) }
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(model.statusText == "完成" ? .secondary : .primary)
                    .lineLimit(2)
                Spacer()
                if !model.hasKey {
                    Button("設定 Key", action: onSettings)
                        .font(.caption)
                }
            }
        }
        .padding(20)
        .frame(width: 480, height: 485)
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
                    Text("只有你按快捷鍵或「開始」時，選取文字才會送往 Gemini。免費層級的內容可能被 Google 用於改進產品。")
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
        .frame(width: 510, height: 565)
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
