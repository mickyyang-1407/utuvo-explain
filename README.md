<p align="center"><img src="docs/assets/cat-512.webp" width="112" height="112" alt="UTUVO 的橘白貓咪"></p>

<h1 align="center">UTUVO Explain</h1>
<p align="center"><strong>貓貓翻譯家。選一段字，就地看懂。</strong></p>
<p align="center"><a href="https://mickyyang-1407.github.io/utuvo-explain/">產品網站</a> · <a href="https://github.com/mickyyang-1407/utuvo-explain/releases/latest">下載 DMG</a> · <a href="README.en.md">English</a> · <a href="LICENSE">MIT</a></p>

<p align="center"><img src="docs/assets/explain-app.webp" width="540" alt="UTUVO Explain 真實畫面：WebAssembly 句子的白話解釋"></p>

**macOS 14+ · Apple Silicon 安裝包 · SwiftUI + AppKit · 自備 Gemini API Key**

## 兩個快捷鍵，兩種讀法

| 快捷鍵 | 結果 |
| --- | --- |
| `⌥D` | 以台灣繁體中文白話解釋選取文字，必要時補充術語或背景 |
| `⌥⇧D` | 非中文翻成台灣繁體中文；中文翻成英文，只顯示譯文 |

視窗會盡量貼近選字。若目標 App 沒有提供選字內容或位置，也可在視窗中手動貼字。結果可複製，兩個模式可在視窗內切換。

## 安裝與設定

1. 從 [Releases](https://github.com/mickyyang-1407/utuvo-explain/releases/latest) 下載 `UTUVO-Explain-0.1.0-arm64.dmg`，開啟後把 App 拖進「Applications」。安裝包已完成 Developer ID 簽章與 Apple 公證。
2. 從「應用程式」啟動 UTUVO Explain。在右上角設定貼上自己的 [Gemini API Key](https://aistudio.google.com/api-keys)。Key 儲存在 Mac 鑰匙圈。
3. 首次使用時，在 macOS「裝置控制和資料取用」允許 UTUVO Explain。此權限用於取得當下選字與辨識全域快捷鍵；App 不記錄其他按鍵。
4. 選字後按快捷鍵，或在小視窗手動貼上文字。

App 免費且 MIT 開源。Google 的 Gemini API 免費額度、速率限制與資料使用規則由 Google 決定；使用前請查看 [官方價格與資料使用說明](https://ai.google.dev/gemini-api/docs/pricing)。只有你觸發解釋或翻譯時，該段文字才會送往 Google。請勿送出不適合交給第三方處理的敏感文字。App 不保存結果歷史。

## 自行編譯

需要 Xcode 與 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。原始碼沒有內嵌 API Key，也沒有第三方執行階段套件。

```sh
xcodegen generate
xcodebuild -project UTUVOExplain.xcodeproj -scheme UTUVOExplain -configuration Debug build
```

`Scripts/build-release.sh` 需要 Developer ID 憑證；`Scripts/package-release.sh` 另需 Apple 公證用的 Keychain profile。發行版目前只驗證 Apple Silicon，Intel Mac 尚未驗證。個別 App 若不提供輔助使用的選字內容，Explain 會嘗試暫時複製選字並還原剪貼簿；無法安全保留剪貼簿時會要求手動貼上。

## 開源

歡迎提出 issue 或小而清楚的 PR。[MIT 授權](LICENSE)；發現安全問題請參閱 [SECURITY.md](SECURITY.md)。

網站與 README 只使用壓縮後的 WebP 圖片；上方貓咪約 30 KB、App 截圖約 90 KB，避免 GitHub 頁面長時間等待大圖。
