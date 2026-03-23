import SwiftUI
import UIKit

struct ReadingView: View {
    let folder: URL
    let images: [URL]
    let startURL: URL

    @State private var index: Int = 0
    @State private var translation: TranslationResult?
    @State private var dragOffsets: [Int: CGSize] = [:]

    private let translationStore = TranslationStore()

    var body: some View {
        Group {
            if images.isEmpty {
                ContentUnavailableView("无图片", systemImage: "photo")
            } else {
                TabView(selection: $index) {
                    ForEach(Array(images.enumerated()), id: \.element.path) { i, url in
                        pageView(url: url)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
        }
        .navigationTitle("阅读")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let i = images.firstIndex(where: { $0.path == startURL.path }) {
                index = i
            }
            loadTranslation()
        }
        .onChange(of: index) { _, _ in
            loadTranslation()
            dragOffsets = [:]
        }
    }

    @ViewBuilder
    private func pageView(url: URL) -> some View {
        GeometryReader { geo in
            if let ui = UIImage(contentsOfFile: url.path) {
                let size: CGSize
                if let cg = ui.cgImage {
                    size = CGSize(width: CGFloat(cg.width), height: CGFloat(cg.height))
                } else {
                    size = CGSize(width: ui.size.width * ui.scale, height: ui.size.height * ui.scale)
                }
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay {
                            bubbleOverlay(in: geo.size, imageSize: size)
                        }
                }
            } else {
                ContentUnavailableView("无法加载图片", systemImage: "exclamationmark.triangle")
            }
        }
    }

    @ViewBuilder
    private func bubbleOverlay(in container: CGSize, imageSize: CGSize) -> some View {
        let layout = aspectFitLayout(container: container, imageSize: imageSize)
        let t = translation
        let opacity = Double(AppSettings.translationBubbleOpacityPercent) / 100.0
        ForEach(t?.bubbles ?? []) { bubble in
            let base = mapRect(bubble.rect, layout: layout)
            let offset = dragOffsets[bubble.id] ?? .zero
            Text(bubble.text)
                .font(.system(size: max(11, layout.scale * 14), weight: .medium))
                .foregroundStyle(.primary)
                .padding(8)
                .background(.ultraThinMaterial.opacity(opacity))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .position(x: base.midX + offset.width, y: base.midY + offset.height)
                .gesture(
                    DragGesture()
                        .onChanged { g in
                            var next = dragOffsets
                            next[bubble.id] = g.translation
                            dragOffsets = next
                        }
                )
        }
    }

    private func loadTranslation() {
        guard index >= 0, index < images.count else {
            translation = nil
            return
        }
        translation = translationStore.load(forImage: images[index])
    }

    private struct AspectFit {
        var scale: CGFloat
        var offsetX: CGFloat
        var offsetY: CGFloat
    }

    private func aspectFitLayout(container: CGSize, imageSize: CGSize) -> AspectFit {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return AspectFit(scale: 1, offsetX: 0, offsetY: 0)
        }
        let s = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * s
        let h = imageSize.height * s
        let ox = (container.width - w) / 2
        let oy = (container.height - h) / 2
        return AspectFit(scale: s, offsetX: ox, offsetY: oy)
    }

    private func mapRect(_ r: CGRect, layout: AspectFit) -> CGRect {
        CGRect(
            x: layout.offsetX + r.minX * layout.scale,
            y: layout.offsetY + r.minY * layout.scale,
            width: r.width * layout.scale,
            height: r.height * layout.scale
        )
    }
}
