import Foundation
import CoreGraphics

enum TranslationLanguage: String, CaseIterable, Identifiable {
    case jaZh = "JA_TO_ZH"
    case enZh = "EN_TO_ZH"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .jaZh: return "日文 → 中文"
        case .enZh: return "英文 → 中文"
        }
    }

    var visionRecognitionLanguages: [String] {
        switch self {
        case .jaZh: return ["ja-JP", "zh-Hans", "en-US"]
        case .enZh: return ["en-US"]
        }
    }

    var ocrCacheMode: String {
        switch self {
        case .jaZh: return "ios_vision_ja"
        case .enZh: return "ios_vision_en"
        }
    }
}

enum BubbleSource: String, Codable {
    case bubbleDetector = "bubble_detector"
    case textDetector = "text_detector"
    case manual = "manual"
    case unknown = "unknown"
}

struct BubbleTranslation: Identifiable, Equatable, Hashable {
    var id: Int
    var rect: CGRect
    var text: String
    var source: BubbleSource

    init(id: Int, rect: CGRect, text: String, source: BubbleSource = .unknown) {
        self.id = id
        self.rect = rect
        self.text = text
        self.source = source
    }
}

struct TranslationResult: Equatable {
    var imageName: String
    var width: Int
    var height: Int
    var bubbles: [BubbleTranslation]
}

struct OcrBubble: Equatable {
    var id: Int
    var rect: CGRect
    var text: String
    var source: BubbleSource
}

struct PageOcrResult: Equatable {
    var imageName: String
    var width: Int
    var height: Int
    var bubbles: [OcrBubble]
    var cacheMode: String
}
