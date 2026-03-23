# 漫画翻译 iOS（Manga Translator iOS）

基于 [jedzqer/manga-translator-android](https://github.com/jedzqer/manga-translator-android) 的使用场景与数据格式，在 iOS 上实现的漫画翻译应用：**漫画库 → Vision 文字识别 → LLM 整页翻译 → 阅读页叠加可拖动气泡**。翻译结果 JSON、`glossary.json` 与 OCR 缓存文件命名规则与 Android 版对齐，便于将来互相同步或对照。

## 功能概览

- **漫画库**：在沙盒 `Application Support/manga_library/` 下管理文件夹；支持从相册导入、**CBZ/ZIP（解压后新建文件夹）**、以及从「文件」App **递归导入文件夹**（适用于 EhViewer 等导出目录）。
- **快速翻译**：独立标签页，从相册或**剪贴板图片**单张走完整 OCR + 翻译流程（iOS 无法在其它 App 上层显示系统级悬浮窗，此为替代方案）。
- **OCR**：使用 **Apple Vision**（`VNRecognizeTextRequest`）识别日文/英文并合并为气泡区域；**未内置 Android 端 ONNX 推理**（若需与安卓一致，需自行集成 ONNX Runtime Mobile / Core ML 等）。
- **OCR 模型路径**：默认 **`Application Support/MangaTranslator/ocr_models/`**（启动时自动创建）。可在 **设置 → OCR 模型路径** 填写本机**绝对路径**覆盖；同页会列出与 Android `assets/` 对齐的文件名及是否已放入目录。将 Hugging Face 等处下载的 `.onnx` 按原名拷贝到该目录即可（当前版本仍以 Vision 为主，路径供同步与后续扩展）。
- **翻译 API**：**OpenAI 兼容**（`/v1/chat/completions`）与 **Google Gemini**（`generateContent`，与 Android `ApiFormat.GEMINI` 对齐）；共用 `llm_prompts.json`，解析 `translation` / `glossary_used` 与 `<b>...</b>` 分段。
- **批量翻译保活**：翻译文件夹时**禁止自动锁屏**并申请 **UIKit 后台任务**，减轻切出应用后中断的概率（行为上接近 Android 前台服务，但受 iOS 后台策略限制）。
- **阅读**：横向翻页（`TabView`），在原图上叠加译文气泡，支持拖动。

## 依赖

- Swift Package：**[ZIPFoundation](https://github.com/weichsel/ZIPFoundation)**（解析 CBZ/ZIP）。首次用 Xcode 打开工程时会自动解析。

## 环境要求

- Xcode 15+（建议）
- iOS **17.0+**
- 自备 API：OpenAI 兼容或 Gemini（见应用内设置说明）

## 构建与运行

1. 打开 `ios/MangaTranslator/MangaTranslator.xcodeproj`，等待 Swift Package 解析完成。
2. 运行 **MangaTranslator** 目标。
3. 在 **设置** 中选择接口类型并填写地址、Key、模型；在 **漫画库** 中管理作品并翻译。

## 单元测试

工程内已包含 **MangaTranslatorTests** 目标（不访问网络、不依赖真机相机）：

- **Xcode**：`Product → Test` 或快捷键 **⌘U**。
- **命令行**（需在 macOS 上安装 Xcode / `xcodebuild`）：

```bash
cd ios/MangaTranslator
xcodebuild test -scheme MangaTranslator -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

当前用例覆盖：`TextProcessing`（`<b>` 分段、英文 OCR 归一化）、`TranslationStore` / `GlossaryStore` / `OcrStore` 的磁盘读写与缓存键逻辑。

## 与 Android 版仍存在的差异

| 项目 | Android | 本 iOS 版 |
|------|---------|-----------|
| 气泡检测 / OCR | 本地 ONNX（多模型） | 系统 Vision |
| 悬浮窗翻译（跨 App 叠加） | 支持 | **系统不支持**；请用「快速翻译」或先导入漫画库 |
| 前台服务 | 支持 | 后台任务 + 禁用锁屏（能力有限） |
| Share Extension / 系统分享菜单直达 | 可扩展 | 未实现（可按需增加 Extension 目标） |
| 远程 OCR（仅 API） | 支持 | 未实现 |

## 致谢

逻辑与资源组织参考 [manga-translator-android](https://github.com/jedzqer/manga-translator-android)；OCR 与 UI 为针对 iOS 的重新实现。
