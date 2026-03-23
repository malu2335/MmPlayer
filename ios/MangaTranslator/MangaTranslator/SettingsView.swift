import SwiftUI

struct SettingsView: View {
    @State private var apiUrl = AppSettings.apiUrl
    @State private var apiKey = AppSettings.apiKey
    @State private var modelName = AppSettings.modelName
    @State private var apiFormat = AppSettings.apiFormat
    @State private var timeout = AppSettings.apiTimeoutSeconds
    @State private var temperature = AppSettings.llmTemperature
    @State private var opacityPercent = AppSettings.translationBubbleOpacityPercent
    @State private var ocrModelsDirectoryPath = AppSettings.ocrModelsDirectoryPath

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

                Section {
                    TextField("自定义模型目录（绝对路径，可留空）", text: $ocrModelsDirectoryPath)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text(OcrModelPaths.resolvedRootDirectory().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } header: {
                    Text("OCR 模型路径")
                } footer: {
                    Text("默认将使用上述路径。若填写自定义路径，须为已存在的文件夹。请把与 Android 版 `assets/` 同名的 `.onnx` 文件放入该目录；当前版本仍使用系统 Vision 识别，模型文件供后续 ONNX 接入或自行同步使用。")
                }

                Section("模型文件检测") {
                    ForEach(OcrModelPaths.catalogWithExistence(), id: \.file) { row in
                        HStack {
                            Image(systemName: row.exists ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(row.exists ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.file)
                                    .font(.caption)
                                    .textSelection(.enabled)
                                Text(row.note)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section(footer: Text("Gemini 示例根地址：https://generativelanguage.googleapis.com/v1beta；模型示例：gemini-1.5-flash。翻译 JSON 与 Android 兼容。")) {
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
                ocrModelsDirectoryPath = AppSettings.ocrModelsDirectoryPath
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
        AppSettings.ocrModelsDirectoryPath = ocrModelsDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
