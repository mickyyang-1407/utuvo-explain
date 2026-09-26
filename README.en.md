<p align="center"><img src="docs/assets/cat-512.webp" width="112" height="112" alt="The orange and cream UTUVO cat"></p>

<h1 align="center">UTUVO Explain</h1>
<p align="center"><strong>Select text. Understand it where you found it.</strong></p>
<p align="center"><a href="https://mickyyang-1407.github.io/utuvo-explain/en.html">Website</a> · <a href="https://github.com/mickyyang-1407/utuvo-explain/releases/latest">Download</a> · <a href="README.md">繁體中文</a> · <a href="LICENSE">MIT</a></p>

<p align="center"><img src="docs/assets/explain-app.webp" width="540" alt="Actual UTUVO Explain window explaining a WebAssembly sentence in Traditional Chinese"></p>

**macOS 14+ · Apple Silicon installer · SwiftUI + AppKit · Your own Gemini API key**

## Two shortcuts

| Shortcut | Result |
| --- | --- |
| `⌥D` | A plain-language explanation in Taiwan Traditional Chinese, with essential context when useful |
| `⌥⇧D` | Other languages to Taiwan Traditional Chinese; Chinese to English, with translation only |
| `⌥S` | Drag over any part of the screen, recognize the text, then explain it (images, video subtitles, scanned PDFs) |
| `⌥⇧S` | Drag over part of the screen and translate the text |

### Framing the screen

| ① Press `⌥S` and frame the subtitle | ② Release — the window appears |
| --- | --- |
| <img src="docs/assets/step-frame.webp" width="420" alt="Illustration of framing an English subtitle in a video window"> | <img src="docs/assets/step-explain.webp" width="420" alt="UTUVO Explain window next to the video, explaining the subtitle"> |

**Tutorial video** (1:35, Chinese narration): [watch on the site](https://mickyyang-1407.github.io/utuvo-explain/en.html#screen).

A four-page tutorial opens on first launch and stays available from the menu bar (使用教學…).

While framing, press Space to pick a whole window or Esc to cancel. Text recognition runs on your Mac; only the recognized text is sent to Gemini, and the captured image is deleted right after recognition. The recognized text appears in the source field, where you can fix typos before sending again.

The compact window tries to appear near your selected text. You can also paste text manually, switch modes in the window, and copy the result. The app interface is currently in Traditional Chinese.

## Install

1. Download `UTUVO-Explain-0.1.1-arm64.dmg` from [Releases](https://github.com/mickyyang-1407/utuvo-explain/releases/latest) and drag the app into Applications. The installer is Developer ID signed and Apple notarized.
2. Launch UTUVO Explain and add your own [Gemini API key](https://aistudio.google.com/api-keys) in Settings. It stays in macOS Keychain.
3. Allow UTUVO Explain under macOS “Device Control and Data Access” when prompted. The app uses this access to read the current selection and recognize global shortcuts; it does not record other keystrokes.
4. The first time you use `⌥S`, allow UTUVO Explain under “Screen & System Audio Recording”, then relaunch the app.
5. Select text and press a shortcut, or paste text into the window.

The app is free and MIT licensed. Google's free-tier limits, rate limits and data-use rules are set by Google; see its [official pricing and data-use page](https://ai.google.dev/gemini-api/docs/pricing). Selected text is sent to Google only when you trigger an action. Do not submit sensitive text that should not be shared with a third party. The app does not keep result history.

## Build from source

Install Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
xcodebuild -project UTUVOExplain.xcodeproj -scheme UTUVOExplain -configuration Debug build
```

No API key is embedded in the source and no third-party runtime package is used. Release scripts require your own Developer ID identity and Apple notarization profile. The installer has only been verified on Apple Silicon; Intel has not been tested. If a target app does not expose its selected text, Explain may briefly copy the selection and restore the clipboard. It skips that fallback if it cannot safely preserve the clipboard.

Contributions and focused issues are welcome. [MIT License](LICENSE) · [Security policy](SECURITY.md).

README images are optimized WebP: the cat is about 30 KB and the app screenshot about 90 KB.
