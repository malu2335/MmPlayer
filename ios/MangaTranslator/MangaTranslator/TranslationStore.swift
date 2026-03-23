import Foundation

final class TranslationStore {
    func translationURL(forImage imageURL: URL) -> URL {
        let dir = imageURL.deletingLastPathComponent()
        let base = imageURL.deletingPathExtension().lastPathComponent
        return dir.appendingPathComponent("\(base).json")
    }

    func load(forImage imageURL: URL) -> TranslationResult? {
        let jsonURL = translationURL(forImage: imageURL)
        guard let data = try? Data(contentsOf: jsonURL) else { return nil }
        return parseTranslationJSON(data, fallbackImageName: imageURL.lastPathComponent)
    }

    func save(_ result: TranslationResult, forImage imageURL: URL) throws {
        let jsonURL = translationURL(forImage: imageURL)
        let obj = NSMutableDictionary()
        obj["image"] = result.imageName
        obj["width"] = result.width
        obj["height"] = result.height
        let bubbles = NSMutableArray()
        for b in result.bubbles {
            let item: [String: Any] = [
                "id": b.id,
                "left": Double(b.rect.minX),
                "top": Double(b.rect.minY),
                "right": Double(b.rect.maxX),
                "bottom": Double(b.rect.maxY),
                "text": b.text,
                "source": b.source.rawValue
            ]
            bubbles.add(item)
        }
        obj["bubbles"] = bubbles
        let json = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted])
        try json.write(to: jsonURL)
    }

    private func parseTranslationJSON(_ data: Data, fallbackImageName: String) -> TranslationResult? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let imageName = (root["image"] as? String) ?? fallbackImageName
        let width = (root["width"] as? Int) ?? 0
        let height = (root["height"] as? Int) ?? 0
        guard let arr = root["bubbles"] as? [[String: Any]] else {
            return TranslationResult(imageName: imageName, width: width, height: height, bubbles: [])
        }
        var bubbles: [BubbleTranslation] = []
        for (i, item) in arr.enumerated() {
            let id = (item["id"] as? Int) ?? i
            let left = CGFloat((item["left"] as? Double) ?? 0)
            let top = CGFloat((item["top"] as? Double) ?? 0)
            let right = CGFloat((item["right"] as? Double) ?? 0)
            let bottom = CGFloat((item["bottom"] as? Double) ?? 0)
            let text = (item["text"] as? String) ?? ""
            let sourceRaw = item["source"] as? String
            let source = BubbleSource(rawValue: sourceRaw ?? "") ?? .unknown
            bubbles.append(BubbleTranslation(id: id, rect: CGRect(x: left, y: top, width: right - left, height: bottom - top), text: text, source: source))
        }
        return TranslationResult(imageName: imageName, width: width, height: height, bubbles: bubbles)
    }
}
