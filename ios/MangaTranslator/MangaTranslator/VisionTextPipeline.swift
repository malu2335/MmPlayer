import Foundation
import UIKit
import Vision

enum VisionPipelineError: Error {
    case noImage
    case visionFailed(Error)
}

/// 使用系统 Vision 文字识别，将邻近文本行合并为「气泡」区域（无需 Android 端 ONNX 模型）。
final class VisionTextPipeline {
    func ocrPage(imageURL: URL, language: TranslationLanguage) async throws -> PageOcrResult {
        guard let image = UIImage(contentsOfFile: imageURL.path),
              let cgImage = image.cgImage else {
            throw VisionPipelineError.noImage
        }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let observations = try await recognizeText(cgImage: cgImage, language: language)
        let merged = mergeObservations(observations, imageSize: size)
        let bubbles: [OcrBubble] = merged.enumerated().map { i, m in
            OcrBubble(id: i, rect: m.rect, text: m.text, source: .bubbleDetector)
        }
        return PageOcrResult(
            imageName: imageURL.lastPathComponent,
            width: Int(size.width),
            height: Int(size.height),
            bubbles: bubbles,
            cacheMode: language.ocrCacheMode
        )
    }

    private func recognizeText(cgImage: CGImage, language: TranslationLanguage) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err {
                    cont.resume(throwing: VisionPipelineError.visionFailed(err))
                    return
                }
                let results = (req.results as? [VNRecognizedTextObservation]) ?? []
                cont.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = language.visionRecognitionLanguages
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                cont.resume(throwing: VisionPipelineError.visionFailed(error))
            }
        }
    }

    private struct MergedLine {
        var rect: CGRect
        var text: String
    }

    /// Vision 的 boundingBox 为归一化坐标，原点在左下角；转换为左上角原点、像素坐标。
    private func convertBox(_ observation: VNRecognizedTextObservation, imageSize: CGSize) -> CGRect {
        let b = observation.boundingBox
        let x = b.minX * imageSize.width
        let w = b.width * imageSize.width
        let h = b.height * imageSize.height
        let y = (1 - b.maxY) * imageSize.height
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func mergeObservations(_ observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [MergedLine] {
        var boxes: [(rect: CGRect, text: String)] = []
        for obs in observations {
            guard let cand = obs.topCandidates(1).first else { continue }
            let t = cand.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            boxes.append((convertBox(obs, imageSize: imageSize), t))
        }
        guard !boxes.isEmpty else { return [] }
        boxes.sort { $0.rect.minY < $1.rect.minY }

        var parent = Array(0..<boxes.count)
        func find(_ i: Int) -> Int {
            if parent[i] != i { parent[i] = find(parent[i]) }
            return parent[i]
        }
        func union(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[rb] = ra }
        }

        for i in 0..<boxes.count {
            for j in (i + 1)..<boxes.count {
                if shouldMerge(boxes[i].rect, boxes[j].rect) {
                    union(i, j)
                }
            }
        }

        var clusters: [Int: [Int]] = [:]
        for i in 0..<boxes.count {
            let r = find(i)
            clusters[r, default: []].append(i)
        }

        var merged: [MergedLine] = []
        for (_, indices) in clusters {
            let sortedIdx = indices.sorted { boxes[$0].rect.minY < boxes[$1].rect.minY }
            var unionRect = boxes[sortedIdx[0]].rect
            var texts: [String] = []
            for idx in sortedIdx {
                unionRect = unionRect.union(boxes[idx].rect)
                texts.append(boxes[idx].text)
            }
            merged.append(MergedLine(rect: unionRect, text: texts.joined(separator: "\n")))
        }
        merged.sort { $0.rect.minY < $1.rect.minY }
        return merged
    }

    private func horizontalOverlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let left = max(a.minX, b.minX)
        let right = min(a.maxX, b.maxX)
        return max(0, right - left)
    }

    private func shouldMerge(_ a: CGRect, _ b: CGRect) -> Bool {
        let h = max(max(a.height, b.height), 8)
        let vertDist: CGFloat
        if a.maxY <= b.minY {
            vertDist = b.minY - a.maxY
        } else if b.maxY <= a.minY {
            vertDist = a.minY - b.maxY
        } else {
            vertDist = 0
        }
        if vertDist > h * 1.25 { return false }
        let overlap = horizontalOverlap(a, b)
        let minW = min(a.width, b.width)
        if minW <= 0 { return false }
        return overlap / minW > 0.12 || overlap > 10
    }
}
