import Foundation

final class GlossaryStore {
    func glossaryURL(forFolder folder: URL) -> URL {
        folder.appendingPathComponent("glossary.json")
    }

    func load(folder: URL) -> [String: String] {
        let url = glossaryURL(forFolder: folder)
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        var map: [String: String] = [:]
        for (k, v) in obj {
            if let s = v as? String, !k.isEmpty, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                map[k] = s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return map
    }

    func save(_ glossary: [String: String], folder: URL) throws {
        let url = glossaryURL(forFolder: folder)
        let obj = NSMutableDictionary()
        for (k, v) in glossary where !k.isEmpty && !v.isEmpty {
            obj[k] = v
        }
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted])
        try data.write(to: url)
    }
}
