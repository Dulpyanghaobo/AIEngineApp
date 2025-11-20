//
//  CatProfile.swift
//  AIEngineApp
//
//  Created by i564407 on 11/18/25.
//

import SwiftUI
import FoundationModels

// MARK: - 演示用结构化数据 --------------------------------------------

/// 文档示例：Generable 类型定义
/// 注意：即使应用支持多语言，代码中的 Generable 描述和字段名通常保持为英语（支持的语言），
/// 以确保模型能准确理解结构定义。
@Generable(description: "Basic profile information about a cat")
struct CatProfile {
    var name: String
    
    @Guide(description: "The age of the cat", .range(0...20))
    var age: Int
    
    @Guide(description: "One sentence about this cat's personality")
    var profile: String
}

// MARK: - 演示场景枚举 --------------------------------------------

enum MultilingualScenario: String, CaseIterable, Identifiable {
    case checkSupport
    case forceOutputLanguage
    case localeContext
    case unsupportedError
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .checkSupport: return "Check Locale Support"
        case .forceOutputLanguage: return "Force Output Language"
        case .localeContext: return "Locale Specifics (en_US vs en_GB)"
        case .unsupportedError: return "Handle Unsupported Language"
        }
    }
    
    var description: String {
        switch self {
        case .checkSupport:
            return "Verify if specific locales are supported before calling the model."
        case .forceOutputLanguage:
            return "Input is Spanish, but Instructions force English output."
        case .localeContext:
            return "Using 'The person's locale is...' to affect word choice (e.g., Elevator vs Lift)."
        case .unsupportedError:
            return "Trigger and catch the .unsupportedLanguageOrLocale error."
        }
    }
}

// MARK: - 主演示 View ------------------------------------------------

@MainActor
struct MultilingualDemoView: View {
    
    // MARK: - State
    @State private var selectedScenario: MultilingualScenario = .checkSupport
    
    // Inputs
    @State private var userPrompt: String = "" // 模拟用户的输入
    @State private var targetLocaleIdentifier: String = Locale.current.identifier
    @State private var shouldForceLanguage: Bool = true
    
    // Outputs
    @State private var outputText: String = ""
    @State private var isGenerating: Bool = false
    @State private var availabilityMessage: String = ""
    @State private var errorDetail: String?
    
    // Demo Presets
    let testLocales = ["en_US", "es_ES", "zh_CN", "fr_FR", "xx_XX"] // xx_XX 用于测试不支持的情况
    
    var body: some View {
        Form {
            // MARK: - 场景选择
            Section("Scenario") {
                Picker("Select Demo", selection: $selectedScenario) {
                    ForEach(MultilingualScenario.allCases) { scenario in
                        Text(scenario.title).tag(scenario)
                    }
                }
                Text(selectedScenario.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - 动态配置区域
            Section("Configuration") {
                if selectedScenario == .checkSupport {
                    Picker("Test Locale", selection: $targetLocaleIdentifier) {
                        ForEach(testLocales, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }
                    
                    Button("Check Support via supportsLocale()") {
                        checkLocaleSupport()
                    }
                    
                    if !availabilityMessage.isEmpty {
                        Text(availabilityMessage)
                            .font(.footnote)
                            .foregroundColor(availabilityMessage.contains("Yes") ? .green : .red)
                    }
                } else {
                    // 输入区域
                    VStack(alignment: .leading) {
                        Text("User Input:")
                            .font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $userPrompt)
                            .frame(height: 80)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                    }
                    
                    // 场景特定的控制
                    if selectedScenario == .forceOutputLanguage {
                        Toggle("Add 'MUST respond in English' instruction", isOn: $shouldForceLanguage)
                        Text("Without this, model might reply in Spanish because the input is Spanish.")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    
                    if selectedScenario == .localeContext {
                        Picker("Simulate Locale", selection: $targetLocaleIdentifier) {
                            Text("United States (en_US)").tag("en_US")
                            Text("United Kingdom (en_GB)").tag("en_GB")
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            
            // MARK: - 运行模型
            if selectedScenario != .checkSupport {
                Section("Run") {
                    Button {
                        Task { await runGeneration() }
                    } label: {
                        HStack {
                            if isGenerating { ProgressView() }
                            Text(isGenerating ? "Generating..." : "Generate Response")
                        }
                    }
                    .disabled(isGenerating)
                }
                
                Section("Output") {
                    if let error = errorDetail {
                        VStack(alignment: .leading) {
                            Label("Language Error", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } else if !outputText.isEmpty {
                        Text(outputText)
                    } else {
                        Text("Response will appear here.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            
            // MARK: - Code Snippet / Explanation
            Section("Documentation Insight") {
                switch selectedScenario {
                case .localeContext:
                    Text("Uses helper: `func localeInstructions(for locale: Locale)` to inject 'The person's locale is...'")
                        .font(.caption)
                case .unsupportedError:
                    Text("Catches: `LanguageModelSession.GenerationError.unsupportedLanguageOrLocale`")
                        .font(.caption)
                default:
                    EmptyView()
                }
            }
        }
        .navigationTitle("Multilingual Support")
        .onChange(of: selectedScenario) { newValue in
            resetUI(for: newValue)
        }
    }
    
    // MARK: - Logic & Helpers
    
    private func resetUI(for scenario: MultilingualScenario) {
        outputText = ""
        errorDetail = nil
        availabilityMessage = ""
        
        switch scenario {
        case .forceOutputLanguage:
            // 模拟混合输入：Prompt 是西语，期望回答是英语
            userPrompt = "Hola, ¿cómo estás? Escribe un poema corto sobre el sol."
            shouldForceLanguage = true
        case .localeContext:
            // 测试词汇差异 (电梯: Elevator vs Lift)
            userPrompt = "What do I use to go up to the 10th floor?"
            targetLocaleIdentifier = "en_US"
        case .unsupportedError:
            // 模拟不支持的语言 (假设 model 不支持克林贡语或乱码，具体取决于当前 model 版本)
            // 注意：Guardrails 对于不支持语言可能失效
            userPrompt = "tlhIngan Hol Dajatlh'a'?" // Klingon: Do you speak Klingon?
        default:
            break
        }
    }
    
    /// 文档功能点：检查语言支持
    private func checkLocaleSupport() {
        let locale = Locale(identifier: targetLocaleIdentifier)
        // API调用: supportsLocale(_:)
        // By default, uses current, but checks if model supports this locale.
        let isSupported = SystemLanguageModel.default.supportsLocale(locale)
        
        if isSupported {
            availabilityMessage = "Yes, '\(targetLocaleIdentifier)' is supported (or compatible)."
        } else {
            availabilityMessage = "No, '\(targetLocaleIdentifier)' is NOT supported."
        }
    }
    
    /// 文档推荐的 Helper Function
    /// Start with the exact phrase in English... reduces hallucinations.
    private func localeInstructions(for localeIdentifier: String) -> String {
        let locale = Locale(identifier: localeIdentifier)
        
        // Skip for US English (base model training)
        if Locale(identifier: "en_US").identifier == locale.identifier {
            return "" // 文档建议 US 跳过
        } else {
            // "The person's locale is \(locale.identifier)."
            return "The person's locale is \(locale.identifier)."
        }
    }

    private func runGeneration() async {
        isGenerating = true
        outputText = ""
        errorDetail = nil
        
        // 构建 Instructions
        var instructions = "You are a helpful assistant."
        
        // 1. 处理 Locale Context
        if selectedScenario == .localeContext {
            let localePhrase = localeInstructions(for: targetLocaleIdentifier)
            if !localePhrase.isEmpty {
                instructions += "\n\(localePhrase)"
            }
        }
        
        // 2. 处理强制输出语言
        if selectedScenario == .forceOutputLanguage && shouldForceLanguage {
            // You can phrase this request... "You MUST respond in [Language]"
            instructions += "\nYou MUST respond in English."
        }
        
        do {
            let session = LanguageModelSession(instructions: instructions)
            
            // 3. 处理不支持的语言错误
            // 如果输入包含了模型无法识别或不支持的语言，会抛出错误
            let response = try await session.respond(to: userPrompt)
            outputText = response.content
            
        } catch LanguageModelSession.GenerationError.unsupportedLanguageOrLocale(let localeIdentifier) {
            // Handle the error by communicating to the person...
            errorDetail = "Error: Unsupported Language/Locale detected: \(localeIdentifier)."
        } catch {
            errorDetail = "Generation Error: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
}
