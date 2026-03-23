import Foundation

struct LlmTranslationResult {
    var translation: String
    var glossaryUsed: [String: String]
}

enum LlmError: Error, LocalizedError {
    case notConfigured
    case invalidResponse(String)
    case http(Int, String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "请先在设置中填写 API 地址、Key 与模型。"
        case .invalidResponse(let s): return "模型返回格式无效：\(s.prefix(200))"
        case .http(let c, let b): return "HTTP \(c): \(b.prefix(300))"
        case .network(let e): return e.localizedDescription
        }
    }
}

private struct PromptConfig {
    var systemPrompt: String
    var userPromptPrefix: String
    var exampleMessages: [(role: String, content: String)]
}

final class LlmClient {
    private var promptCache: [String: PromptConfig] = [:]

    func translate(
        pageText: String,
        glossary: [String: String],
        promptAssetName: String = "llm_prompts"
    ) async throws -> LlmTranslationResult {
        guard AppSettings.isApiConfigured() else { throw LlmError.notConfigured }
        let config = try loadPromptConfig(name: promptAssetName)
        let userPayload = buildUserPayload(text: pageText, glossary: glossary)
        let format = AppSettings.apiFormat.lowercased()

        if format == "gemini" {
            return try await translateGemini(config: config, userPayload: userPayload)
        }
        return try await translateOpenAI(config: config, userPayload: userPayload)
    }

    // MARK: - OpenAI 兼容

    private func translateOpenAI(config: PromptConfig, userPayload: String) async throws -> LlmTranslationResult {
        let messages = buildOpenAiMessages(config: config, userPayload: userPayload)
        let model = selectModel()
        let url = try buildChatCompletionsURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppSettings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: buildOpenAiBody(model: model, messages: messages))
        request.timeoutInterval = TimeInterval(AppSettings.apiTimeoutSeconds)

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfHttpError(data: data, response: response)
        guard let raw = parseOpenAiContent(data: data) else {
            throw LlmError.invalidResponse(String(data: data, encoding: .utf8) ?? "")
        }
        return try parseTranslationContent(raw)
    }

    private func buildOpenAiMessages(config: PromptConfig, userPayload: String) -> [[String: Any]] {
        var messages: [[String: Any]] = [
            ["role": "system", "content": config.systemPrompt]
        ]
        for ex in config.exampleMessages {
            messages.append(["role": ex.role, "content": ex.content])
        }
        messages.append(["role": "user", "content": config.userPromptPrefix + userPayload])
        return messages
    }

    private func buildChatCompletionsURL() throws -> URL {
        var base = AppSettings.apiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        if base.hasSuffix("/models") {
            base = String(base.dropLast("/models".count))
            while base.hasSuffix("/") { base.removeLast() }
        }
        let path: String
        if base.hasSuffix("/v1/chat/completions") {
            path = ""
        } else if base.hasSuffix("/v1") {
            path = "/chat/completions"
        } else {
            path = "/v1/chat/completions"
        }
        guard let url = URL(string: base + path) else {
            throw LlmError.invalidResponse("API 地址无效")
        }
        return url
    }

    private func buildOpenAiBody(model: String, messages: [[String: Any]]) -> [String: Any] {
        [
            "model": model,
            "messages": messages,
            "temperature": AppSettings.llmTemperature
        ]
    }

    // MARK: - Gemini（与 Android `LlmClient` 行为对齐）

    private func translateGemini(config: PromptConfig, userPayload: String) async throws -> LlmTranslationResult {
        let url = try buildGeminiGenerateURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: buildGeminiBody(config: config, userPayload: userPayload))
        request.timeoutInterval = TimeInterval(AppSettings.apiTimeoutSeconds)

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfHttpError(data: data, response: response)
        if let errMsg = parseGeminiErrorMessage(data: data) {
            throw LlmError.http((response as? HTTPURLResponse)?.statusCode ?? 400, errMsg)
        }
        guard let raw = parseGeminiTextContent(data: data) else {
            throw LlmError.invalidResponse(String(data: data, encoding: .utf8) ?? "")
        }
        return try parseTranslationContent(raw)
    }

    private func buildGeminiGenerateURL() throws -> URL {
        let model = normalizeGeminiModelName(selectModel())
        var base = AppSettings.apiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        let endpoint: String
        if base.contains(":generateContent") {
            endpoint = base
        } else if base.hasSuffix("/v1beta") || base.hasSuffix("/v1") {
            endpoint = "\(base)/\(model):generateContent"
        } else {
            endpoint = "\(base)/v1beta/\(model):generateContent"
        }
        let withKey = appendGeminiApiKey(to: endpoint, key: AppSettings.apiKey)
        guard let url = URL(string: withKey) else {
            throw LlmError.invalidResponse("Gemini URL 无效")
        }
        return url
    }

    private func normalizeGeminiModelName(_ modelName: String) -> String {
        var trimmed = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasPrefix("/") { trimmed.removeFirst() }
        if trimmed.lowercased().hasPrefix("models/") { return trimmed }
        return "models/\(trimmed)"
    }

    private func appendGeminiApiKey(to urlString: String, key: String) -> String {
        let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
        let sep = urlString.contains("?") ? "&" : "?"
        return urlString + sep + "key=" + encoded
    }

    private func buildGeminiBody(config: PromptConfig, userPayload: String) -> [String: Any] {
        var contents: [[String: Any]] = []
        for ex in config.exampleMessages {
            let lower = ex.role.lowercased()
            let role = (lower == "assistant" || lower == "model") ? "model" : "user"
            contents.append([
                "role": role,
                "parts": [["text": ex.content]]
            ])
        }
        let userText = config.userPromptPrefix + userPayload
        contents.append([
            "role": "user",
            "parts": [["text": userText]]
        ])
        var body: [String: Any] = ["contents": contents]
        if !config.systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": config.systemPrompt]]
            ]
        }
        body["generationConfig"] = [
            "temperature": AppSettings.llmTemperature,
            "responseMimeType": "application/json"
        ]
        return body
    }

    private func parseGeminiErrorMessage(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = json["error"] as? [String: Any],
              let msg = err["message"] as? String,
              !msg.isEmpty else { return nil }
        return msg
    }

    private func parseGeminiTextContent(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else { return nil }
        let texts = parts.compactMap { $0["text"] as? String }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let joined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.nilIfEmpty
    }

    // MARK: - 共用

    private func selectModel() -> String {
        let parts = AppSettings.modelName.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.first ?? AppSettings.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func throwIfHttpError(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LlmError.invalidResponse("无 HTTP 响应")
        }
        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw LlmError.http(http.statusCode, text)
        }
    }

    private func loadPromptConfig(name: String) throws -> PromptConfig {
        if let c = promptCache[name] { return c }
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: nil)
            ?? Bundle.main.url(forResource: name, withExtension: "json") else {
            throw LlmError.invalidResponse("找不到资源 \(name).json")
        }
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LlmError.invalidResponse("提示词 JSON 解析失败")
        }
        let system = (root["system_prompt"] as? String) ?? ""
        let prefix = (root["user_prompt_prefix"] as? String) ?? ""
        var examples: [(String, String)] = []
        if let arr = root["example_messages"] as? [[String: Any]] {
            for o in arr {
                let role = (o["role"] as? String) ?? ""
                let content = (o["content"] as? String) ?? ""
                if !role.isEmpty && !content.isEmpty {
                    examples.append((role, content))
                }
            }
        }
        let cfg = PromptConfig(systemPrompt: system, userPromptPrefix: prefix, exampleMessages: examples)
        promptCache[name] = cfg
        return cfg
    }

    private func buildUserPayload(text: String, glossary: [String: String]) -> String {
        var g: [String: String] = [:]
        for (k, v) in glossary where !k.isEmpty && !v.isEmpty { g[k] = v }
        let payload: [String: Any] = ["text": text, "glossary": g]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func parseOpenAiContent(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else { return nil }
        if let s = message["content"] as? String {
            return s.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        if let parts = message["content"] as? [[String: Any]] {
            var texts: [String] = []
            for p in parts {
                if let t = p["text"] as? String, !t.isEmpty { texts.append(t) }
                if let t = p["content"] as? String, !t.isEmpty { texts.append(t) }
            }
            let joined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.nilIfEmpty
        }
        return nil
    }

    private func parseTranslationContent(_ content: String) throws -> LlmTranslationResult {
        let cleaned = stripCodeFence(content)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LlmError.invalidResponse(cleaned)
        }
        guard let translation = (json["translation"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !translation.isEmpty else {
            throw LlmError.invalidResponse(cleaned)
        }
        var glossary: [String: String] = [:]
        if let go = json["glossary_used"] as? [String: Any] {
            for (k, v) in go {
                if let s = v as? String, !k.isEmpty, !s.isEmpty {
                    glossary[k] = s.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return LlmTranslationResult(translation: translation, glossaryUsed: glossary)
    }

    private func stripCodeFence(_ content: String) -> String {
        var t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("```"), t.hasSuffix("```") else { return t }
        t = String(t.dropFirst(3).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("json") {
            t = String(t.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
