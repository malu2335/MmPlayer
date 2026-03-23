import PhotosUI
import SwiftUI
import UIKit

/// iOS 无法在其它 App 上层显示系统级悬浮窗；此页提供相册单图 / 剪贴板图片的快速整页翻译，流程与漫画库内单页一致。
struct QuickTranslateView: View {
    @State private var language: TranslationLanguage = .jaZh
    @State private var pickerItem: PhotosPickerItem?
    @State private var busy = false
    @State private var message = ""
    @State private var result: TranslationResult?
    @State private var previewImage: UIImage?
    @State private var showReader = false

    private let service = TranslationService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("iOS 不允许像 Android 那样在任意应用上方显示悬浮翻译球；请使用本页或先将图片存入漫画库。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("语言") {
                    Picker("翻译方向", selection: $language) {
                        ForEach(TranslationLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                }

                Section("图片来源") {
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        Label("从相册选择一张", systemImage: "photo")
                    }
                    .disabled(busy)

                    Button {
                        Task { await translateFromPasteboard() }
                    } label: {
                        Label("使用剪贴板中的图片", systemImage: "doc.on.clipboard")
                    }
                    .disabled(busy || UIPasteboard.general.image == nil)
                }

                if busy {
                    Section {
                        HStack {
                            ProgressView()
                            Text(message).font(.subheadline)
                        }
                    }
                }

                if let result, previewImage != nil {
                    Section {
                        Button("查看翻译叠加层") { showReader = true }
                    }
                }
            }
            .navigationTitle("快速翻译")
            .onChange(of: pickerItem) { _, new in
                guard let new else { return }
                Task { await translatePicked(new) }
            }
            .fullScreenCover(isPresented: $showReader) {
                if let img = previewImage, let result {
                    NavigationStack {
                        QuickTranslateOverlayView(image: img, result: result)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("关闭") { showReader = false }
                                }
                            }
                    }
                }
            }
        }
    }

    private func tempImageURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("quick_\(UUID().uuidString).jpg")
    }

    private func translatePicked(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await MainActor.run { message = "无法读取图片" }
            return }
        await runTranslate(data: data)
        await MainActor.run { pickerItem = nil }
    }

    private func translateFromPasteboard() async {
        guard let img = UIPasteboard.general.image,
              let data = img.jpegData(compressionQuality: 0.92) else {
            await MainActor.run { message = "剪贴板中没有图片" }
            return
        }
        await runTranslate(data: data)
    }

    private func runTranslate(data: Data) async {
        await MainActor.run {
            busy = true
            message = "处理中…"
            result = nil
            previewImage = UIImage(data: data)
        }
        let url = tempImageURL()
        do {
            try data.write(to: url)
            var glossary: [String: String] = [:]
            let tempFolder = url.deletingLastPathComponent()
            let out = try await service.translateImage(
                at: url,
                folder: tempFolder,
                glossary: &glossary,
                language: language,
                forceOcr: true,
                progress: { msg in
                    Task { @MainActor in message = msg }
                }
            )
            try? FileManager.default.removeItem(at: url)
            await MainActor.run {
                result = out
                busy = false
                message = out == nil ? "未完成翻译" : "完成"
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            await MainActor.run {
                busy = false
                message = error.localizedDescription
            }
        }
    }
}

private struct QuickTranslateOverlayView: View {
    let image: UIImage
    let result: TranslationResult
    @State private var dragOffsets: [Int: CGSize] = [:]

    var body: some View {
        GeometryReader { geo in
            let size: CGSize
            if let cg = image.cgImage {
                size = CGSize(width: CGFloat(cg.width), height: CGFloat(cg.height))
            } else {
                size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
            }
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .overlay {
                        bubbleLayer(container: geo.size, imageSize: size)
                    }
            }
        }
    }

    private func bubbleLayer(container: CGSize, imageSize: CGSize) -> some View {
        let layout = aspectFit(container: container, imageSize: imageSize)
        let opacity = Double(AppSettings.translationBubbleOpacityPercent) / 100.0
        return ForEach(result.bubbles) { bubble in
            let base = mapRect(bubble.rect, layout: layout)
            let off = dragOffsets[bubble.id] ?? .zero
            Text(bubble.text)
                .font(.system(size: max(11, layout.scale * 14), weight: .medium))
                .padding(8)
                .background(.ultraThinMaterial.opacity(opacity))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .position(x: base.midX + off.width, y: base.midY + off.height)
                .gesture(
                    DragGesture().onChanged { g in
                        var next = dragOffsets
                        next[bubble.id] = g.translation
                        dragOffsets = next
                    }
                )
        }
    }

    private struct Layout {
        var scale: CGFloat
        var offsetX: CGFloat
        var offsetY: CGFloat
    }

    private func aspectFit(container: CGSize, imageSize: CGSize) -> Layout {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return Layout(scale: 1, offsetX: 0, offsetY: 0)
        }
        let s = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * s
        let h = imageSize.height * s
        return Layout(scale: s, offsetX: (container.width - w) / 2, offsetY: (container.height - h) / 2)
    }

    private func mapRect(_ r: CGRect, layout: Layout) -> CGRect {
        CGRect(
            x: layout.offsetX + r.minX * layout.scale,
            y: layout.offsetY + r.minY * layout.scale,
            width: r.width * layout.scale,
            height: r.height * layout.scale
        )
    }
}
