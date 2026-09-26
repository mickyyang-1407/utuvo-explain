# Changelog

## 0.2.0 — 2026-09-26

- `⌥S` / `⌥⇧S`: frame a region of the screen, recognize its text on-device with Vision, then explain or translate it. Also available from the menu bar and a “框選螢幕” button in the window.
- The captured image stays local and is deleted after recognition; only the recognized text is sent to Gemini.
- Recognition gives up after 20 seconds with a retry message instead of waiting forever on a busy Neural Engine.
- Screen Recording permission is requested only when `⌥S` is first used; the window explains how to enable it.
- The window appears with a “recognizing” state the moment framing ends, returns to where it was, and a second `⌥S` during recognition starts a new frame instead of being ignored.
- New four-page tutorial (first launch, and 使用教學… in the menu bar) with real screenshots.
- Results are normalized to Traditional Chinese characters (Gemini occasionally mixed in simplified ones such as 时间).
- Gemini gets 60 seconds instead of 30; timeouts and offline errors are shown in Chinese.

## 0.1.0 — 2026-09-23

- First public release of UTUVO Explain, the cat-themed macOS selection helper.
- `⌥D` explains selected text in Taiwan Traditional Chinese; `⌥⇧D` translates it.
- Uses the user's Gemini API key stored in macOS Keychain; includes editable prompts and model name.
- Shows the result near the selection when the target app provides its bounds; offers manual paste when needed.
- Native SwiftUI/AppKit interface, Apple Silicon installer, Developer ID signing, and Apple notarization.
