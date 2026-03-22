import Foundation

final class LibraryRepository {
    private let rootURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        rootURL = base.appendingPathComponent("manga_library", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    var libraryRoot: URL { rootURL }

    func listFolders() -> [URL] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return urls.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    func createFolder(name: String) -> URL? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        guard !trimmed.isEmpty, !trimmed.contains("..") else { return nil }
        let folder = rootURL.appendingPathComponent(trimmed, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: folder.path) else { return nil }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        } catch {
            return nil
        }
    }

    func listImages(in folder: URL) -> [URL] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return urls.filter { isImageFile($0) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    func deleteFolder(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    func renameFolder(at url: URL, newName: String) -> URL? {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        guard !trimmed.isEmpty, !trimmed.contains("..") else { return nil }
        let dest = rootURL.appendingPathComponent(trimmed, isDirectory: true)
        guard url.lastPathComponent != trimmed, !FileManager.default.fileExists(atPath: dest.path) else {
            return url.lastPathComponent == trimmed ? url : nil
        }
        do {
            try FileManager.default.moveItem(at: url, to: dest)
            migrateFolderPreferences(from: url.path, to: dest.path)
            return dest
        } catch {
            return nil
        }
    }

    /// 复制导入的图片到文件夹（由调用方从 PhotosPicker 等提供 Data）。
    func importImageData(_ data: Data, suggestedName: String, into folder: URL) -> URL? {
        let name = uniqueFileName(suggestedName, in: folder)
        let dest = folder.appendingPathComponent(name)
        do {
            try data.write(to: dest)
            return dest
        } catch {
            return nil
        }
    }

    private func migrateFolderPreferences(from oldPath: String, to newPath: String) {
        let d = UserDefaults.standard
        let lang = d.string(forKey: AppSettings.translationLanguageKey(forFolderPath: oldPath))
        if let lang {
            d.set(lang, forKey: AppSettings.translationLanguageKey(forFolderPath: newPath))
            d.removeObject(forKey: AppSettings.translationLanguageKey(forFolderPath: oldPath))
        }
    }

    private func uniqueFileName(_ fileName: String, in folder: URL) -> String {
        let ext = (fileName as NSString).pathExtension
        let base = (fileName as NSString).deletingPathExtension
        var candidate = fileName
        var i = 1
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            let suffix = ext.isEmpty ? "" : ".\(ext)"
            candidate = "\(base)_\(i)\(suffix)"
            i += 1
        }
        return candidate
    }

    private func isImageFile(_ url: URL) -> Bool {
        let exts = ["jpg", "jpeg", "png", "webp", "heic", "HEIC"]
        return exts.contains(url.pathExtension.lowercased())
    }
}
