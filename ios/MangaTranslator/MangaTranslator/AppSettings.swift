import Foundation

/// 与 Android `SettingsStore` 使用相同的 UserDefaults suite 键名，便于将来数据对齐。
enum AppSettings {
    private static let suite = UserDefaults.standard

    static var apiUrl: String {
        get { suite.string(forKey: "api_url") ?? "https://api.siliconflow.cn/v1" }
        set { suite.set(newValue, forKey: "api_url") }
    }

    static var apiKey: String {
        get { suite.string(forKey: "api_key") ?? "" }
        set { suite.set(newValue, forKey: "api_key") }
    }

    static var modelName: String {
        get { suite.string(forKey: "model_name") ?? "Qwen/Qwen2.5-7B-Instruct" }
        set { suite.set(newValue, forKey: "model_name") }
    }

    /// 仅实现 OpenAI 兼容接口；`gemini` 可后续扩展。
    static var apiFormat: String {
        get { suite.string(forKey: "api_format") ?? "openai" }
        set { suite.set(newValue, forKey: "api_format") }
    }

    static var apiTimeoutSeconds: Int {
        get {
            let v = suite.integer(forKey: "api_timeout_seconds")
            return v > 0 ? v : 300
        }
        set { suite.set(newValue, forKey: "api_timeout_seconds") }
    }

    static var llmTemperature: Double {
        get {
            if let s = suite.string(forKey: "llm_temperature"), let d = Double(s) { return d }
            return 0.7
        }
        set { suite.set(String(newValue), forKey: "llm_temperature") }
    }

    static var translationBubbleOpacityPercent: Int {
        get {
            let v = suite.integer(forKey: "translation_bubble_opacity_percent")
            return v > 0 ? min(100, v) : 92
        }
        set { suite.set(min(100, max(10, newValue)), forKey: "translation_bubble_opacity_percent") }
    }

    static func isApiConfigured() -> Bool {
        !apiUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func translationLanguageKey(forFolderPath path: String) -> String {
        "translation_language_\(path)"
    }

    static func translationLanguage(forFolderPath path: String) -> TranslationLanguage {
        guard let raw = suite.string(forKey: translationLanguageKey(forFolderPath: path)) else {
            return .jaZh
        }
        return TranslationLanguage(rawValue: raw) ?? .jaZh
    }

    static func setTranslationLanguage(_ lang: TranslationLanguage, forFolderPath path: String) {
        suite.set(lang.rawValue, forKey: translationLanguageKey(forFolderPath: path))
    }

    static func readingProgressKey(folderPath: String, imageName: String) -> String {
        "reading_progress_\(folderPath)_\(imageName)"
    }
}
