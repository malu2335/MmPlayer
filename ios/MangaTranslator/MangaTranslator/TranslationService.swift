import Foundation

/// 对应 Android `TranslationPipeline` 的核心流程：OCR（Vision）→ LLM 整页翻译 → 写入与 Android 兼容的 JSON。
final class TranslationService {
    private let vision = VisionTextPipeline()
    private let ocrStore = OcrStore()
    private let translationStore = TranslationStore()
    private let llm = LlmClient()

    func translateImage(
        at imageURL: URL,
        folder: URL,
        glossary: inout [String: String],
        language: TranslationLanguage,
        forceOcr: Bool,
        progress: @escaping (String) -> Void
    ) async throws -> TranslationResult? {
        guard AppSettings.isApiConfigured() else {
            progress("请先配置翻译 API")
            return nil
        }

        let cacheMode = language.ocrCacheMode
        if !forceOcr, let cached = ocrStore.load(forImage: imageURL, expectedCacheMode: cacheMode) {
            progress("使用 OCR 缓存…")
            return try await translatePageOcr(cached, imageURL: imageURL, glossary: &glossary, language: language, progress: progress)
        }

        progress("正在识别文字…")
        let page = try await vision.ocrPage(imageURL: imageURL, language: language)
        try ocrStore.save(page, forImage: imageURL)
        return try await translatePageOcr(page, imageURL: imageURL, glossary: &glossary, language: language, progress: progress)
    }

    private func translatePageOcr(
        _ page: PageOcrResult,
        imageURL: URL,
        glossary: inout [String: String],
        language: TranslationLanguage,
        progress: @escaping (String) -> Void
    ) async throws -> TranslationResult {
        let bubbles = page.bubbles
        let translatable = bubbles.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if translatable.isEmpty {
            let empty = bubbles.map { BubbleTranslation(id: $0.id, rect: $0.rect, text: "", source: $0.source) }
            return TranslationResult(
                imageName: imageURL.lastPathComponent,
                width: page.width,
                height: page.height,
                bubbles: empty
            )
        }

        progress("正在调用模型翻译…")
        let pageText = translatable.map { bubble in
            let text = normalizeOcrText(bubble.text, language: language)
            return "<b>\(text)</b>"
        }.joined(separator: "\n")

        let translated: LlmTranslationResult
        do {
            translated = try await llm.translate(pageText: pageText, glossary: glossary)
        } catch {
            progress("翻译失败：\(error.localizedDescription)")
            let fallback = bubbles.map { b in
                let t = b.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return BubbleTranslation(id: b.id, rect: b.rect, text: t, source: b.source)
            }
            return TranslationResult(imageName: imageURL.lastPathComponent, width: page.width, height: page.height, bubbles: fallback)
        }

        for (k, v) in translated.glossaryUsed {
            glossary[k] = v
        }

        let segments = extractTaggedSegments(from: translated.translation, expectedCount: translatable.count)
        var map: [Int: String] = [:]
        for i in translatable.indices {
            map[translatable[i].id] = segments[i]
        }
        let outBubbles = bubbles.map { b in
            BubbleTranslation(id: b.id, rect: b.rect, text: map[b.id] ?? "", source: b.source)
        }
        return TranslationResult(
            imageName: imageURL.lastPathComponent,
            width: page.width,
            height: page.height,
            bubbles: outBubbles
        )
    }
}
