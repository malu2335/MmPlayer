import SwiftUI

struct SettingsView: View {
    @State private var apiUrl = AppSettings.apiUrl
    @State private var apiKey = AppSettings.apiKey
    @State private var modelName = AppSettings.modelName
    @State private var timeout = AppSettings.apiTimeoutSeconds
    @State private var temperature = AppSettings.llmTemperature
    @State private var opacityPercent = AppSettings.translationBubbleOpacityPercent

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenAI 兼容 API") {
                    TextField("API 地址（以 /v1 结尾）", text: $apiUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API Key", text: $apiKey)
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

                Section(footer: Text("本应用为 Android 版 manga-translator 的 iOS 移植：使用 Vision 做 OCR，翻译 JSON 与 Android 兼容。详细说明见仓库 README。")) {
                    EmptyView()
                }
            }
            .navigationTitle("设置")
        }
    }

    private func save() {
        AppSettings.apiUrl = apiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        AppSettings.apiKey = apiKey
        AppSettings.modelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        AppSettings.apiTimeoutSeconds = timeout
        AppSettings.llmTemperature = temperature
        AppSettings.translationBubbleOpacityPercent = opacityPercent
    }
}
