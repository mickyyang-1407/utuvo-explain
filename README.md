# UTUVO Explain

Mac 選字工具：按 `⌥D` 看白話解釋（意思與必要背景），按 `⌥⇧D` 翻譯（只給譯文；中文轉英文，其他語言轉台灣繁中）。也能在小視窗貼文字，點「白話解釋」或「翻譯」。使用 Gemini API 免費額度，預設模型 `gemini-3.5-flash-lite`。

## 開始使用

1. 目前試用版已安裝於 `~/Applications/UTUVO Explain.app`；雙擊即可開啟。若要自行重建，執行下方指令。
2. 開啟 App 後，點右上角齒輪，在 [Google AI Studio](https://aistudio.google.com/api-keys) 的 Free Tier 專案建立 API Key，貼上並儲存。Key 只存於 Mac 鑰匙圈，不要貼在聊天裡。
3. 第一次使用時，點 App 裡的「開啟系統設定」，在 macOS「裝置控制和資料取用」允許 UTUVO Explain。權限用於讀取你當下選取的文字，並識別 `⌥D`／`⌥⇧D`；不紀錄其他按鍵。
4. 在瀏覽器或其他 App 選字，按快捷鍵。只有按快捷鍵或「白話解釋」／「翻譯」按鈕時，文字才會送到 Gemini。

快捷鍵叫出的視窗會盡量出現在選字附近；目標 App 若不提供選字位置，則退回滑鼠附近。
結果視窗已開啟時，可以直接按另一個快捷鍵，對目前原文切換白話解釋或翻譯。

```sh
Scripts/build-release.sh
open 'build/Build/Products/Release/UTUVO Explain.app'
```

免費 Gemini API 有額度限制，免費層級的內容可能用於改進 Google 產品；不要送出敏感資料。原型不保存翻譯歷史，不會自動覆寫選取文字或剪貼簿，單次最多送出 6,000 字。遇到無法讀取選字的 App，可以手動貼到原文欄。
