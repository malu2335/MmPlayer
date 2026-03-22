import Foundation

func normalizeOcrText(_ text: String, language: TranslationLanguage) -> String {
    guard language == .enZh else { return text }
    return text
        .replacingOccurrences(of: "\r", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// 与 Android `extractTaggedSegments` 行为一致。
func extractTaggedSegments(from text: String, expectedCount: Int) -> [String] {
    guard expectedCount > 0 else { return [] }
    let pattern = try! NSRegularExpression(pattern: "<b>(.*?)</b>", options: [.dotMatchesLineSeparators])
    let range = NSRange(text.startIndex..., in: text)
    let matches = pattern.matches(in: text, options: [], range: range)
    let segments = matches.compactMap { m -> String? in
        guard m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if segments.isEmpty {
        if expectedCount == 1 { return [text.trimmingCharacters(in: .whitespacesAndNewlines)] }
        return Array(repeating: "", count: expectedCount)
    }
    var result = Array(repeating: "", count: expectedCount)
    let limit = min(expectedCount, segments.count)
    for i in 0..<limit {
        result[i] = segments[i]
    }
    return result
}
