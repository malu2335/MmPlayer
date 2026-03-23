import Foundation
import ZIPFoundation

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

    struct CbzImportOutcome {
        let folder: URL?
        let importedCount: Int
    }

    /// 从用户通过文件选择器授权的 CBZ/ZIP 解压图片到新建的漫画文件夹（与 Android `importCbz` 行为类似）。
    func importCbzArchive(fromSecurityScoped sourceURL: URL) -> CbzImportOutcome {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let archiveName = sourceURL.lastPathComponent
        let folderBase = (archiveName as NSString).deletingPathExtension
        let folderName = folderBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "cbz_import"
            : folderBase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let folder = createUniqueFolder(baseName: folderName) else {
            return CbzImportOutcome(folder: nil, importedCount: 0)
        }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("cbz_\(UUID().uuidString).zip")
        do {
            try FileManager.default.copyItem(at: sourceURL, to: temp)
            defer { try? FileManager.default.removeItem(at: temp) }
            guard let archive = try? Archive(url: temp, accessMode: .read) else {
                try? FileManager.default.removeItem(at: folder)
                return CbzImportOutcome(folder: nil, importedCount: 0)
            }
            var count = 0
            for entry in archive {
                guard entry.type == .file else { continue }
                if entry.path.contains("..") { continue }
                let name = URL(fileURLWithPath: entry.path, isDirectory: false).lastPathComponent
                guard !name.isEmpty, isImageFile(URL(fileURLWithPath: name)) else { continue }
                let destName = uniqueFileName(name, in: folder)
                let dest = folder.appendingPathComponent(destName)
                do {
                    _ = try archive.extract(entry, to: dest)
                    count += 1
                } catch {
                    continue
                }
            }
            if count == 0 {
                try? FileManager.default.removeItem(at: folder)
                return CbzImportOutcome(folder: nil, importedCount: 0)
            }
            return CbzImportOutcome(folder: folder, importedCount: count)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            return CbzImportOutcome(folder: nil, importedCount: 0)
        }
    }

    /// 递归导入「文件」App 中选中文件夹内的所有图片（适用于 EhViewer 等导出目录）。
    func importImagesRecursively(fromSecurityScoped sourceURL: URL, into libraryFolder: URL) -> Int {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDir), isDir.boolValue else {
            return 0
        }
        guard let enumerator = FileManager.default.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var count = 0
        while let itemURL = enumerator.nextObject() as? URL {
            guard (try? itemURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            guard isImageFile(itemURL) else { continue }
            guard let data = try? Data(contentsOf: itemURL) else { continue }
            let name = itemURL.lastPathComponent
            if importImageData(data, suggestedName: name, into: libraryFolder) != nil {
                count += 1
            }
        }
        return count
    }

    private func createUniqueFolder(baseName: String) -> URL? {
        let sanitized = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        guard !sanitized.isEmpty, !sanitized.contains("..") else { return nil }
        var index = 0
        while true {
            let name = index == 0 ? sanitized : "\(sanitized)_\(index)"
            let folder = rootURL.appendingPathComponent(name, isDirectory: true)
            if !FileManager.default.fileExists(atPath: folder.path) {
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    return folder
                } catch {
                    return nil
                }
            }
            index += 1
        }
    }
}
