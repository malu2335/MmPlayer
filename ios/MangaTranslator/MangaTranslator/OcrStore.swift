import Foundation

final class OcrStore {
    func ocrURL(forImage imageURL: URL) -> URL {
        let dir = imageURL.deletingLastPathComponent()
        let base = imageURL.deletingPathExtension().lastPathComponent
        return dir.appendingPathComponent("\(base).ocr.json")
    }

    func load(forImage imageURL: URL, expectedCacheMode: String?) -> PageOcrResult? {
        let url = ocrURL(forImage: imageURL)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let cacheMode = (root["ocrCacheMode"] as? String) ?? ""
        if let expected = expectedCacheMode, !expected.isEmpty, cacheMode != expected {
            return nil
        }
        let imageName = (root["image"] as? String) ?? imageURL.lastPathComponent
        let width = (root["width"] as? Int) ?? 0
        let height = (root["height"] as? Int) ?? 0
        guard let arr = root["bubbles"] as? [[String: Any]] else { return nil }
        var bubbles: [OcrBubble] = []
        for (i, item) in arr.enumerated() {
            let id = (item["id"] as? Int) ?? i
            let left = CGFloat((item["left"] as? Double) ?? 0)
            let top = CGFloat((item["top"] as? Double) ?? 0)
            let right = CGFloat((item["right"] as? Double) ?? 0)
            let bottom = CGFloat((item["bottom"] as? Double) ?? 0)
            let text = (item["text"] as? String) ?? ""
            let source = BubbleSource(rawValue: (item["source"] as? String) ?? "") ?? .unknown
            bubbles.append(OcrBubble(id: id, rect: CGRect(x: left, y: top, width: right - left, height: bottom - top), text: text, source: source))
        }
        return PageOcrResult(imageName: imageName, width: width, height: height, bubbles: bubbles, cacheMode: cacheMode)
    }

    func save(_ result: PageOcrResult, forImage imageURL: URL) throws {
        let jsonURL = ocrURL(forImage: imageURL)
        let obj = NSMutableDictionary()
        obj["image"] = result.imageName
        obj["width"] = result.width
        obj["height"] = result.height
        obj["ocrCacheMode"] = result.cacheMode
        let bubbles = NSMutableArray()
        for b in result.bubbles {
            bubbles.add([
                "id": b.id,
                "left": Double(b.rect.minX),
                "top": Double(b.rect.minY),
                "right": Double(b.rect.maxX),
                "bottom": Double(b.rect.maxY),
                "text": b.text,
                "source": b.source.rawValue
            ])
        }
        obj["bubbles"] = bubbles
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted])
        try data.write(to: jsonURL)
    }
}
