import Foundation

/// 与 Android 版 `assets/` 中 ONNX 资源命名对齐，用于约定本机存放位置（当前仍由 Vision 负责 OCR，此路径供拷贝模型与后续接入 ONNX 使用）。
enum OcrModelPaths {
    /// 默认目录：`Application Support/MangaTranslator/ocr_models/`
    static func defaultRootDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("MangaTranslator/ocr_models", isDirectory: true)
    }

    /// 实际使用的根目录：若设置里填写了有效自定义路径则用之，否则为默认目录（并尝试创建）。
    static func resolvedRootDirectory() -> URL {
        let trimmed = AppSettings.ocrModelsDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: trimmed, isDirectory: true)
            }
        }
        let url = defaultRootDirectory()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(for filename: String) -> URL {
        resolvedRootDirectory().appendingPathComponent(filename, isDirectory: false)
    }

    static func fileExists(_ filename: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: filename).path)
    }

    /// 与 Android 构建说明一致的模型文件名（含可选的 `.data` 伴生文件）。
    static let catalog: [(file: String, note: String)] = [
        ("comic-speech-bubble-detector.onnx", "气泡检测"),
        ("encoder_model.onnx", "日文 OCR 编码器"),
        ("decoder_model.onnx", "日文 OCR 解码器"),
        ("en_PP-OCRv5_rec_mobile_infer.onnx", "英文 OCR"),
        ("ysgyolo_1.2_OS1.0.onnx", "文本补检 / 蒙版"),
        ("Multilingual_PP-OCRv3_det_infer.onnx", "英文行检测"),
        ("migan_512.onnx", "嵌字抹除"),
        ("migan_512.onnx.data", "migan 数据块（若需要）")
    ]

    static func catalogWithExistence() -> [(file: String, note: String, exists: Bool)] {
        catalog.map { ($0.file, $0.note, fileExists($0.file)) }
    }
}
