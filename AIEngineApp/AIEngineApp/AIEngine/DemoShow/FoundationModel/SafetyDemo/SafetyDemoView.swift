import SwiftUI
import FoundationModels

// MARK: - 演示用数据结构 --------------------------------------------

/// 演示场景枚举
enum SafetyScenario: String, CaseIterable, Identifiable {
    case basicGuardrails
    case handleRefusalGuided
    case inputBoundary
    case permissiveMode
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .basicGuardrails: return "Handle Guardrails & Refusals"
        case .handleRefusalGuided: return "Refusal in Guided Gen"
        case .inputBoundary: return "Input Boundaries (Fixed Prompts)"
        case .permissiveMode: return "Permissive Guardrails"
        }
    }
    
    var description: String {
        switch self {
        case .basicGuardrails:
            return "Standard session catching guardrail violations and refusal messages."
        case .handleRefusalGuided:
            return "Handling the specific .refusal error when requesting structured output."
        case .inputBoundary:
            return "Restricting input to a fixed set of Enums to prevent injection."
        case .permissiveMode:
            return "Using .permissiveContentTransformations to analyze sensitive text without blocking."
        }
    }
}

/// 文档中的示例：用于输出边界的 Enum
@Generable
enum Breakfast: String, CaseIterable {
    case waffles
    case pancakes
    case bagels
    case eggs
}

/// 文档中的示例：用于输入边界的 Enum
enum TopicOptions: String, CaseIterable, Identifiable {
    case family
    case nature
    case work
    
    var id: String { rawValue }
}

// MARK: - Safety Demo View ------------------------------------------------

@MainActor
struct SafetyDemoView: View {
    
    // MARK: - State
    
    @State private var selectedScenario: SafetyScenario = .basicGuardrails
    
    // Input States
    @State private var freeTextInput: String = "How to make a potion?"
    @State private var selectedTopic: TopicOptions = .nature
    
    // Instructions
    @State private var instructions: String = """
    You are a helpful assistant.
    If asked about unsafe topics, strictly refuse.
    """
    
    // Output States
    @State private var outputText: String = ""
    @State private var outputColor: Color = .primary
    @State private var isGenerating: Bool = false
    @State private var errorDetail: String?
    
    var body: some View {
        Form {
            // MARK: - 场景选择
            Section("Safety Scenario") {
                Picker("Scenario", selection: $selectedScenario) {
                    ForEach(SafetyScenario.allCases) { scenario in
                        Text(scenario.title).tag(scenario)
                    }
                }
                .pickerStyle(.menu)
                
                Text(selectedScenario.description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - 输入区域 (根据场景变化)
            Section("Input & Configuration") {
                // Instructions (Universal)
                VStack(alignment: .leading) {
                    Text("System Instructions:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $instructions)
                        .frame(height: 60)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                }
                
                Divider()
                
                // Prompt Input
                if selectedScenario == .inputBoundary {
                    Picker("Select Safe Topic", selection: $selectedTopic) {
                        ForEach(TopicOptions.allCases) { topic in
                            Text(topic.rawValue.capitalized).tag(topic)
                        }
                    }
                } else {
                    Text("User Prompt:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $freeTextInput)
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                    
                    // 快捷填入测试用例
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button("Safe Prompt") { freeTextInput = "Write a poem about clouds." }
                            Button("Sensitive Prompt") { freeTextInput = "Write a hateful joke about people." } // 触发 Guardrail
                            Button("Off-topic (Refusal)") { freeTextInput = "Calculate 2934 * 1231" } // 触发 Refusal (取决于模型能力)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
            }
            
            // MARK: - 执行按钮
            Section("Run") {
                Button {
                    Task { await runSafetyTest() }
                } label: {
                    HStack {
                        if isGenerating { ProgressView() }
                        Text(isGenerating ? "Checking Safety & Generating..." : "Generate Response")
                    }
                }
                .disabled(isGenerating)
            }
            
            // MARK: - 结果输出
            Section("Output") {
                if let error = errorDetail {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Safety Event Triggered", systemImage: "exclamationmark.shield.fill")
                            .foregroundColor(.orange)
                            .font(.headline)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                if !outputText.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Model Response:")
                            .font(.caption).foregroundColor(.secondary)
                        Text(outputText)
                            .foregroundColor(outputColor)
                            .padding(.top, 2)
                    }
                } else if errorDetail == nil {
                    Text("Result will appear here...")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }
            
            // MARK: - 说明 (Educational)
            Section("How it works") {
                VStack(alignment: .leading, spacing: 6) {
                    switch selectedScenario {
                    case .basicGuardrails:
                        Text("• Guardrails check input prompts and output.")
                        Text("• Catches `GuardrailViolation` errors.")
                        Text("• Handles plain text refusals (e.g. 'Sorry I can't...').")
                    case .handleRefusalGuided:
                        Text("• Structured generation has no place for 'Sorry' text.")
                        Text("• Throws `LanguageModelSession.GenerationError.refusal`.")
                        Text("• We catch this and ask the model for an explanation.")
                    case .inputBoundary:
                        Text("• Prevents prompt injection by not allowing open text.")
                        Text("• Uses an Enum to construct the prompt internally.")
                    case .permissiveMode:
                        Text("• Initializes `SystemLanguageModel` with `.permissiveContentTransformations`.")
                        Text("• Skips standard guardrails for tasks like content moderation.")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Safety & Guardrails")
        .onChange(of: selectedScenario) { newValue in
            resetUI(for: newValue)
        }
    }
    
    // MARK: - Logic
    
    private func resetUI(for scenario: SafetyScenario) {
        outputText = ""
        errorDetail = nil
        outputColor = .primary
        
        switch scenario {
        case .basicGuardrails:
            freeTextInput = "Write a story about a robbery."
        case .handleRefusalGuided:
            freeTextInput = "Something sweet" // Will map to Breakfast
        case .inputBoundary:
            selectedTopic = .nature
        case .permissiveMode:
            freeTextInput = "Analyze this rude comment: 'You are terrible!'"
        }
    }
    
    private func runSafetyTest() async {
        isGenerating = true
        outputText = ""
        errorDetail = nil
        outputColor = .primary
        
        do {
            switch selectedScenario {
                
            // 场景 1: 基础 Guardrail 和 文本拒绝
            case .basicGuardrails:
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: freeTextInput)
                outputText = response.content
                
                // 简单的启发式检查：看模型是否口头拒绝了
                if outputText.lowercased().hasPrefix("sorry") || outputText.lowercased().contains("i can't") {
                    outputColor = .orange
                    errorDetail = "Note: The model produced a refusal message."
                }
                
            // 场景 2: 结构化输出时的 Refusal 错误处理
            case .handleRefusalGuided:
                let session = LanguageModelSession(instructions: instructions)
                let prompt = "Pick the ideal breakfast for request: \(freeTextInput)"
                
                // 尝试生成 Breakfast Enum
                let breakfast = try await session.respond(to: prompt, generating: Breakfast.self)
                outputText = "Successfully generated: \(breakfast.content.rawValue)"
                outputColor = .green
                
            // 场景 3: 输入边界 (Input Boundaries)
            case .inputBoundary:
                let session = LanguageModelSession(instructions: instructions)
                // 核心点：不直接使用用户输入的 String，而是使用 Enum 构造 Prompt
                // 参考文档: "Generate a wholesome... prompt... on \(topicChoice)"
                let safePrompt = """
                Generate a wholesome and empathetic journal prompt that helps \
                this person reflect on \(selectedTopic.rawValue).
                """
                
                let response = try await session.respond(to: safePrompt)
                outputText = response.content
                
            // 场景 4: 宽松模式 (Permissive Mode)
            case .permissiveMode:
                // 核心点：初始化特殊的 Model
                let permissiveModel = SystemLanguageModel(guardrails: .permissiveContentTransformations)
                
                // 检查可用性 (Permissive 模式也需要检查)
                if case .unavailable = permissiveModel.availability {
                    throw AIEngineError.modelNotAvailable
                }
                
                // 创建 Session (必须传入这个特定的 model)
                // 注意：LanguageModelSession 初始化默认用 default model，这里需要指定 custom model 逻辑
                // 但当前的 API Session 绑定通常是自动的。
                // 根据文档: "let model = SystemLanguageModel(...) ... The session skips guardrail checks"
                // 在实际 beta API 中，通常需要从 Model 创建 Session 或指定配置。
                // 假设 API 支持传入 model 或 options (此处演示概念):
                
                /* 注意：标准 SDK 中 LanguageModelSession 可能暂时不支持直接传入 SystemLanguageModel 实例。
                   如果当前 SDK 版本不支持，此部分仅为概念演示。
                   文档原文: "let model = SystemLanguageModel(...) ... use permissiveContentTransformations"
                */
                
                let session = LanguageModelSession(instructions: instructions)
                
                // *虽然我们在代码里没法显式绑定 permissiveModel 到 session (取决于具体 SDK 版本)*
                // *但文档建议这是初始化的方式。如果 SDK 不支持显式绑定，通常意味着它是全局配置或特定的 options*
                // 这里我们演示标准的调用，但在真实 App 中你可能需要特定的 API 入口点。
                
                let response = try await session.respond(to: freeTextInput)
                outputText = "Analysis Result (Permissive): \(response.content)"
            }
            
        } catch LanguageModelSession.GenerationError.guardrailViolation(let details) {
            // 核心功能点：处理 Guardrail 违规
            errorDetail = "Guardrail Violation Triggered!"
            outputText = "Blocked content. Details: \(String(describing: details))"
            outputColor = .red
            
        } catch LanguageModelSession.GenerationError.refusal(let refusal, _) {
            // 核心功能点：处理 Guided Generation 的拒绝
            errorDetail = "Model Refused Request (Structured Generation Error)"
            outputColor = .orange
            
            // 尝试获取拒绝的解释
            if let explanation = try? await refusal.explanation {
                outputText = "Refusal Explanation: \(explanation)"
            } else {
                outputText = "The model refused to generate the requested type."
            }
            
        } catch {
            errorDetail = "Error: \(error.localizedDescription)"
            outputColor = .red
        }
        
        isGenerating = false
    }
}
