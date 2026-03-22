import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct FolderDetailView: View {
    let folder: URL
    @ObservedObject var library: LibraryViewModel

    @StateObject private var translationActivity = BackgroundTranslationActivity()
    @State private var images: [URL] = []
    @State private var glossary: [String: String] = [:]
    @State private var language: TranslationLanguage = .jaZh
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var translating = false
    @State private var progressMessage = ""
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showCbzImporter = false
    @State private var showFolderImporter = false
    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false

    private let glossaryStore = GlossaryStore()
    private let translationStore = TranslationStore()
    private let translationService = TranslationService()

    var body: some View {
        List {
            Section {
                Picker("翻译语言", selection: $language) {
                    ForEach(TranslationLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .onChange(of: language) { _, new in
                    AppSettings.setTranslationLanguage(new, forFolderPath: folder.path)
                }

                PhotosPicker(selection: $pickerItems, maxSelectionCount: 100, matching: .images) {
                    Label("从相册导入图片", systemImage: "photo.on.rectangle.angled")
                }
                .disabled(translating)

                Button {
                    showCbzImporter = true
                } label: {
                    Label("导入 CBZ / ZIP（新建文件夹）", systemImage: "doc.zipper")
                }
                .disabled(translating)

                Button {
                    showFolderImporter = true
                } label: {
                    Label("从「文件」导入文件夹（EhViewer 导出等）", systemImage: "folder.badge.plus")
                }
                .disabled(translating)

                Button {
                    Task { await translateAll(forceOcr: false) }
                } label: {
                    Label("翻译文件夹（跳过已有）", systemImage: "character.bubble")
                }
                .disabled(translating || images.isEmpty)

                Button {
                    Task { await translateAll(forceOcr: true) }
                } label: {
                    Label("强制重新 OCR 并翻译", systemImage: "arrow.clockwise")
                }
                .disabled(translating || images.isEmpty)
            }

            if translating {
                Section {
                    HStack {
                        ProgressView()
                        Text(progressMessage)
                            .font(.subheadline)
                    }
                }
            }

            Section("页面 (\(images.count))") {
                ForEach(images, id: \.path) { url in
                    NavigationLink {
                        ReadingView(folder: folder, images: images, startURL: url)
                    } label: {
                        HStack {
                            Text(url.lastPathComponent)
                            Spacer()
                            if translationStore.load(forImage: url) != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(folder.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("重命名文件夹") {
                        renameText = folder.lastPathComponent
                        showRename = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("重命名文件夹", isPresented: $showRename) {
            TextField("名称", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("确定") {
                if let newURL = library.repository.renameFolder(at: folder, newName: renameText) {
                    library.refresh()
                    // 导航栈仍指向旧 URL：由用户返回后重新进入
                    _ = newURL
                }
            }
        }
        .onAppear {
            reload()
        }
        .onChange(of: pickerItems) { _, new in
            Task { await importPhotos(new) }
        }
        .fileImporter(
            isPresented: $showCbzImporter,
            allowedContentTypes: cbzAndZipTypes,
            allowsMultipleSelection: false
        ) { result in
            handleCbzImport(result)
        }
        .fileImporter(
            isPresented: $showFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderImport(result)
        }
        .alert(importAlertTitle, isPresented: $showImportAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importAlertMessage)
        }
    }

    private var cbzAndZipTypes: [UTType] {
        var list: [UTType] = [.zip]
        if let cbz = UTType(filenameExtension: "cbz") {
            list.append(cbz)
        }
        return list
    }

    private func handleCbzImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            importAlertTitle = "导入失败"
            importAlertMessage = err.localizedDescription
            showImportAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            let out = library.repository.importCbzArchive(fromSecurityScoped: url)
            importAlertTitle = out.importedCount > 0 ? "CBZ 导入完成" : "CBZ 导入"
            if out.importedCount > 0, let f = out.folder {
                importAlertMessage = "已导入 \(out.importedCount) 张图片到新文件夹「\(f.lastPathComponent)」。请在漫画库中打开该文件夹。"
            } else {
                importAlertMessage = out.importedCount == 0 ? "压缩包中未找到支持的图片。" : "导入未完成。"
            }
            showImportAlert = true
            library.refresh()
            reload()
        }
    }

    private func handleFolderImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            importAlertTitle = "导入失败"
            importAlertMessage = err.localizedDescription
            showImportAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            let n = library.repository.importImagesRecursively(fromSecurityScoped: url, into: folder)
            importAlertTitle = "文件夹导入"
            importAlertMessage = n > 0 ? "已导入 \(n) 张图片到当前文件夹。" : "未从所选文件夹导入到图片（请确认内含 jpg/png/webp 等）。"
            showImportAlert = true
            reload()
            library.refresh()
        }
    }

    private func reload() {
        images = library.repository.listImages(in: folder)
        glossary = glossaryStore.load(folder: folder)
        language = AppSettings.translationLanguage(forFolderPath: folder.path)
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let name = "import_\(UUID().uuidString).jpg"
                _ = library.repository.importImageData(data, suggestedName: name, into: folder)
            }
        }
        await MainActor.run {
            pickerItems = []
            reload()
            library.refresh()
        }
    }

    private func translateAll(forceOcr: Bool) async {
        await MainActor.run {
            translationActivity.begin()
            translating = true
            progressMessage = "准备中…"
        }
        defer {
            Task { @MainActor in
                translationActivity.end()
            }
        }
        var g = glossary
        for (idx, url) in images.enumerated() {
            if !forceOcr, translationStore.load(forImage: url) != nil {
                await MainActor.run {
                    progressMessage = "已跳过 \(idx + 1)/\(images.count)（已有翻译）"
                }
                continue
            }
            await MainActor.run {
                progressMessage = "翻译 \(idx + 1)/\(images.count)…"
            }
            do {
                if let result = try await translationService.translateImage(
                    at: url,
                    folder: folder,
                    glossary: &g,
                    language: language,
                    forceOcr: forceOcr,
                    progress: { msg in
                        Task { @MainActor in progressMessage = msg }
                    }
                ) {
                    try translationStore.save(result, forImage: url)
                }
            } catch {
                await MainActor.run {
                    progressMessage = "错误：\(error.localizedDescription)"
                }
            }
        }
        try? glossaryStore.save(g, folder: folder)
        await MainActor.run {
            glossary = g
            translating = false
            progressMessage = ""
            reload()
        }
    }
}
