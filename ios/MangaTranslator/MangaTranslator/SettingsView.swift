import SwiftUI

struct SettingsView: View {
    @State private var apiUrl = AppSettings.apiUrl
    @State private var apiKey = AppSettings.apiKey
    @State private var modelName = AppSettings.modelName
    @State private var apiFormat = AppSettings.apiFormat
    @State private var timeout = AppSettings.apiTimeoutSeconds
    @State private var temperature = AppSettings.llmTemperature
    @State private var opacityPercent = AppSettings.translationBubbleOpacityPercent

    private let apiFormats: [(id: String, title: String)] = [
        ("openai", "OpenAI 兼容 (/v1/chat/completions)"),
        ("gemini", "Google Gemini (generateContent)")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("翻译 API") {
                    Picker("接口类型", selection: $apiFormat) {
                        ForEach(apiFormats, id: \.id) { item in
                            Text(item.title).tag(item.id)
                        }
                    }
                    TextField(apiFormat == "gemini"
                        ? "API 根地址（如 …/v1beta）"
                        : "API 地址（以 /v1 结尾）", text: $apiUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(apiFormat == "gemini" ? "API Key（将附加到 URL ?key=）" : "API Key", text: $apiKey)
                    TextField("模型名称", text: $modelName)
                        .textInputAutocapitalization(.never)
                    Stepper("超时：\(timeout) 秒", value: $timeout, in: 30...900, step: 30)
                    HStack {
                        Text("温度")
                        Slider(value: $temperature, in: 0...2, step: 0.1)
                        Text(String(format: "%.1f", temperature))
                            .monospacedDigit()
                            .frame(width: 36)
                    }
                }

                Section("阅读") {
                    Stepper("翻译气泡不透明度 \(opacityPercent)%", value: $opacityPercent, in: 30...100, step: 5)
                }

                Section {
                    Button("保存") { save() }
                }

                Section(footer: Text("Gemini 示例根地址：https://generativelanguage.googleapis.com/v1beta；模型示例：gemini-1.5-flash。本应用使用 Vision 做 OCR，翻译 JSON 与 Android 兼容。")) {
                    EmptyView()
                }
            }
            .navigationTitle("设置")
            .onAppear {
                apiUrl = AppSettings.apiUrl
                apiKey = AppSettings.apiKey
                modelName = AppSettings.modelName
                apiFormat = AppSettings.apiFormat
                timeout = AppSettings.apiTimeoutSeconds
                temperature = AppSettings.llmTemperature
                opacityPercent = AppSettings.translationBubbleOpacityPercent
            }
        }
    }

    private func save() {
        AppSettings.apiUrl = apiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        AppSettings.apiKey = apiKey
        AppSettings.modelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        AppSettings.apiFormat = apiFormat
        AppSettings.apiTimeoutSeconds = timeout
        AppSettings.llmTemperature = temperature
        AppSettings.translationBubbleOpacityPercent = opacityPercent
    }
}
