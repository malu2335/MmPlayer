import XCTest
@testable import MangaTranslator

final class TextProcessingTests: XCTestCase {
    func testExtractTaggedSegments_twoBubbles() {
        let raw = "<b>あ</b>\n<b>い</b>"
        let segments = extractTaggedSegments(from: raw, expectedCount: 2)
        XCTAssertEqual(segments, ["あ", "い"])
    }

    func testExtractTaggedSegments_expectedZeroReturnsEmpty() {
        XCTAssertTrue(extractTaggedSegments(from: "x", expectedCount: 0).isEmpty)
    }

    func testExtractTaggedSegments_singleWithoutTagsUsesWholeString() {
        let segments = extractTaggedSegments(from: "整段", expectedCount: 1)
        XCTAssertEqual(segments, ["整段"])
    }

    func testNormalizeOcrText_collapsesEnglishWhitespace() {
        let out = normalizeOcrText("a\nb  \r  c", language: .enZh)
        XCTAssertEqual(out, "a b c")
    }

    func testNormalizeOcrText_japaneseUnchanged() {
        let s = "行1\n行2"
        XCTAssertEqual(normalizeOcrText(s, language: .jaZh), s)
    }
}

final class TranslationStoreTests: XCTestCase {
    func testSaveAndLoad_roundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mt_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("001.jpg")
        try Data().write(to: imageURL)

        let original = TranslationResult(
            imageName: "001.jpg",
            width: 800,
            height: 1200,
            bubbles: [
                BubbleTranslation(
                    id: 0,
                    rect: CGRect(x: 10, y: 20, width: 100, height: 40),
                    text: "译文",
                    source: .bubbleDetector
                )
            ]
        )

        let store = TranslationStore()
        try store.save(original, forImage: imageURL)
        let loaded = store.load(forImage: imageURL)
        XCTAssertNotNil(loaded)
        guard let loaded else { return }
        XCTAssertEqual(loaded.width, 800)
        XCTAssertEqual(loaded.height, 1200)
        XCTAssertEqual(loaded.bubbles.count, 1)
        XCTAssertEqual(loaded.bubbles.first?.text, "译文")
        XCTAssertEqual(loaded.bubbles.first?.id, 0)
        XCTAssertEqual(loaded.bubbles.first?.source, .bubbleDetector)
        XCTAssertEqual(Double(loaded.bubbles.first!.rect.origin.x), 10, accuracy: 0.01)
        XCTAssertEqual(Double(loaded.bubbles.first!.rect.origin.y), 20, accuracy: 0.01)
    }
}

final class GlossaryStoreTests: XCTestCase {
    func testSaveAndLoad() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mt_gloss_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = GlossaryStore()
        try store.save(["莉莉": "Lily", "空": ""], folder: dir)
        let map = store.load(folder: dir)
        XCTAssertEqual(map["莉莉"], "Lily")
        XCTAssertNil(map["空"])
    }
}

final class OcrStoreTests: XCTestCase {
    func testCacheModeMismatchReturnsNil() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mt_ocr_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let imageURL = dir.appendingPathComponent("p.png")
        try Data([0]).write(to: imageURL)

        let page = PageOcrResult(
            imageName: "p.png",
            width: 10,
            height: 10,
            bubbles: [],
            cacheMode: "ios_vision_ja"
        )
        let ocr = OcrStore()
        try ocr.save(page, forImage: imageURL)

        XCTAssertNotNil(ocr.load(forImage: imageURL, expectedCacheMode: "ios_vision_ja"))
        XCTAssertNil(ocr.load(forImage: imageURL, expectedCacheMode: "local_ja"))
    }
}
