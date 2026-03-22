# 漫画翻译 iOS（Manga Translator iOS）

基于 [jedzqer/manga-translator-android](https://github.com/jedzqer/manga-translator-android) 的使用场景与数据格式，在 iOS 上实现的漫画翻译应用：**漫画库 → Vision 文字识别 → OpenAI 兼容 API 整页翻译 → 阅读页叠加可拖动气泡**。翻译结果 JSON、`glossary.json` 与 OCR 缓存文件命名规则与 Android 版对齐，便于将来互相同步或对照。

## 功能概览

- 漫画库：在沙盒 `Application Support/manga_library/` 下管理文件夹，从系统相册批量导入图片。
- OCR：使用 **Apple Vision**（`VNRecognizeTextRequest`）识别日文/英文，并将邻近文本行合并为气泡区域；**不依赖 Android 版 ONNX 模型**（若需与安卓完全一致的检测效果，需后续集成 ONNX Runtime / Core ML 等方案）。
- 翻译：与 Android 相同的 `llm_prompts.json` 提示词流程，请求体为 OpenAI Chat Completions 兼容格式；解析模型返回的 `translation` / `glossary_used` 与 `<b>...</b>` 分段。
- 阅读：横向翻页（`TabView`），在原图上叠加译文气泡，支持拖动（当前会话内；持久化可与 Android 行为对齐后扩展）。

## 环境要求

- Xcode 15+（建议）
- iOS **17.0+**（使用较新的 SwiftUI API）
- 自备 OpenAI 兼容 API（地址需可拼出 `/v1/chat/completions`，与 Android 说明一致）

## 构建与运行

1. 打开 `ios/MangaTranslator/MangaTranslator.xcodeproj`。
2. 选择真机或模拟器，运行 **MangaTranslator**。
3. 在 **设置** 中填写 API 地址、Key、模型名；在 **漫画库** 中新建文件夹并导入图片后，在文件夹内执行翻译。

## 与 Android 版的差异

| 项目 | Android | 本 iOS 版 |
|------|---------|-----------|
| 气泡检测 / OCR | 本地 ONNX（多模型） | 系统 Vision |
| 悬浮窗翻译、EhViewer 导入、前台服务 | 支持 | 未实现 |
| Gemini API | 支持 | 未实现（仅 OpenAI 兼容） |
| CBZ 导入 | 支持 | 未实现（可后续用 ZIP 库扩展） |

## 致谢

逻辑与资源组织参考 [manga-translator-android](https://github.com/jedzqer/manga-translator-android)；OCR 与 UI 为针对 iOS 的重新实现。
