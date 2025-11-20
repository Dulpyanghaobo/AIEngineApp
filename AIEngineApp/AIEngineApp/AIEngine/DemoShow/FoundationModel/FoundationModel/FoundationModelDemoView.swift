//
//  FoundationModelDemoView.swift
//  AIEngineApp
//

import SwiftUI
import Foundation
import FoundationModels

// MARK: - 能力列表（任务级 Prompt） -------------------------------

enum DemoCapability: String, CaseIterable, Identifiable {
    case summarize
    case extractEntities
    case understand
    case refine
    case classify
    case creativeWriting
    case generateTags
    case gameDialog
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .summarize:          return "Summarize"
        case .extractEntities:    return "Extract entities"
        case .understand:         return "Understand text"
        case .refine:             return "Refine / edit text"
        case .classify:           return "Classify / judge text"
        case .creativeWriting:    return "Compose creative writing"
        case .generateTags:       return "Generate tags from text"
        case .gameDialog:         return "Generate game dialog"
        }
    }
    
    /// 对应 Apple 文档里的 Prompt 示例
    var examplePrompt: String {
        switch self {
        case .summarize:
            return "Summarize this article."
        case .extractEntities:
            return "List the people and places mentioned in this text."
        case .understand:
            return "What happens to the dog in this story?"
        case .refine:
            return "Change this story to be in second person."
        case .classify:
            return "Is this text relevant to the topic 'Swift'?"
        case .creativeWriting:
            return "Generate a short bedtime story about a fox."
        case .generateTags:
            return "Provide two tags that describe the main topics of this text."
        case .gameDialog:
            return "Respond in the voice of a friendly inn keeper."
        }
    }
}

// MARK: - 主演示 View ------------------------------------------------

@MainActor
struct FoundationModelDemoView: View {
    
    // 1. 系统语言模型可用性检查
    private let systemModel = SystemLanguageModel.default
    
    // 2. Session（可选：单轮新建 / 多轮复用）
    @State private var session: LanguageModelSession?
    @State private var reuseSession: Bool = true
    
    // 3. Instructions（系统级：角色 + 安全 + 风格）
    @State private var selectedInstructionPreset: InstructionPreset = .writingAssistant
    @State private var maxSentences: Int = 4
    @State private var strictSafety: Bool = true
    
    /// 当前选中的指令模板（由 preset + 参数生成）
    private var currentInstructionTemplate: InstructionTemplate {
        selectedInstructionPreset.template(
            maxSentences: maxSentences,
            strictSafety: strictSafety
        )
    }
    
    // 4. Capability & Prompt（任务级）
    @State private var selectedCapability: DemoCapability = .summarize
    @State private var prompt: String = DemoCapability.summarize.examplePrompt
    
    // 5. Input text（内容级：被分析的原文，例如 OCR / 文件导入）
    @State private var selectedInputPreset: DemoInputPreset = .shortArticle
    @State private var inputText: String = DemoInputPreset.shortArticle.sampleText
    
    // 6. GenerationOptions
    @State private var temperature: Double = 0.7
    
    // 7. 结果 & 状态
    @State private var outputText: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?
    
    /// 用于开发者调试：展示最终发送给模型的 Prompt
    @State private var lastUserPrompt: String = ""
    
    var body: some View {
        Form {
            // MARK: - 模型可用性
            Section("Model Availability") {
                AvailabilityRow(availability: systemModel.availability)
            }
            
            // MARK: - Session 配置
            Section("Session") {
                Toggle("Reuse session for multi-turn conversation", isOn: $reuseSession)
                    .onChange(of: reuseSession) { _ in
                        session = nil
                    }
                
                if reuseSession {
                    Text("When ON, the same LanguageModelSession is reused. The model can keep some context across turns (within the 4096-token context window).")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text("When OFF, a new LanguageModelSession is created for each request (single-turn).")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            
            // MARK: - Instructions（系统级指令：角色 / 安全 / 风格）
            Section("Instructions (system role & safety)") {
                // 选择角色预设（Writing assistant / Summarizer / …）
                Picker("Preset", selection: $selectedInstructionPreset) {
                    ForEach(InstructionPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                
                // 参数：输出长度 / 安全强度
                Stepper(value: $maxSentences, in: 1...10) {
                    Text("Max sentences: \(maxSentences)")
                }
                
                Toggle("Strict safety mode", isOn: $strictSafety)
                
                // 预览：当前模板生成的 Instructions 文本
                VStack(alignment: .leading, spacing: 4) {
                    Text("Effective instructions (preview)")
                        .font(.caption.weight(.semibold))
                    
                    ScrollView {
                        Text(currentInstructionTemplate.textPreview)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(8)
                    }
                    .frame(minHeight: 80, maxHeight: 150)
                }
                
                // 展示真正的 Instructions DSL 用法（可拷贝）
                VStack(alignment: .leading, spacing: 4) {
                    Text("Instructions DSL (copy & reuse)")
                        .font(.caption.weight(.semibold))
                    
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(currentInstructionTemplate.builderSnippet)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(8)
                    }
                    
                    Text("""
                         Instructions are session-level rules. The model obeys these \
                         OVER any per-call prompt. They define role, style, and \
                         safety behavior, and never include untrusted user input.
                         """)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }
            
            // MARK: - Input text（被分析的原文）
            Section("Input text (recognized)") {
                Picker("Preset", selection: $selectedInputPreset) {
                    ForEach(DemoInputPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .onChange(of: selectedInputPreset) { newValue in
                    inputText = newValue.sampleText
                }
                
                TextEditor(text: $inputText)
                    .frame(minHeight: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("说明:")
                        .font(.caption.weight(.semibold))
                    Text("• 这里代表已经识别出的原文，例如 OCR 或文件导入后的文本。")
                    Text("• 你可以通过预设快速切换不同类型的示例文本。")
                    Text("• 也可以直接在下方手动编辑或粘贴自己的文本。")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            // MARK: - Capability & Prompt（任务级）
            Section("Capability & Prompt") {
                Picker("Capability", selection: $selectedCapability) {
                    ForEach(DemoCapability.allCases) { capability in
                        Text(capability.title).tag(capability)
                    }
                }
                .onChange(of: selectedCapability) { newValue in
                    // 切换能力时，自动填充示例 Prompt
                    prompt = newValue.examplePrompt
                }
                
                TextEditor(text: $prompt)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt tips:")
                        .font(.caption.weight(.semibold))
                    Text("• Focus on a single, specific task.")
                    Text("• Use natural language commands or questions.")
                    Text("• Wrap user input inside your own prompt text, rather than sending raw input.")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            // MARK: - GenerationOptions
            Section("Generation Options") {
                HStack {
                    Text("Temperature")
                    Slider(value: $temperature, in: 0...2, step: 0.1)
                    Text(String(format: "%.1f", temperature))
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 40)
                }
                
                Text("""
                     Lower temperature → more deterministic, conservative.
                     Higher temperature → more creative, diverse output.
                     """)
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            // MARK: - 调用模型
            Section("Run") {
                Button {
                    Task {
                        await runGeneration()
                    }
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                        }
                        Text(isGenerating ? "Generating…" : "Generate with on-device model")
                    }
                }
                .disabled(isGenerating || !isModelAvailable)
                
                if !isModelAvailable {
                    Text("Model is not available. Show your fallback UI here.")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            
            // MARK: - Debug：最终发送给模型的 Prompt
            Section("Debug: Prompt sent to model") {
                if lastUserPrompt.isEmpty {
                    Text("Run generation to see the final prompt.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        Text(lastUserPrompt)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 100)
                }
                
                Text("""
                     This is the per-call user prompt only. Session-level \
                     Instructions are applied separately and are not concatenated \
                     into this text.
                     """)
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            // MARK: - 输出结果
            Section("Output") {
                if outputText.isEmpty {
                    Text("The model's response will appear here.")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                } else {
                    ScrollView {
                        Text(outputText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 150)
                }
            }
            
            // MARK: - Capabilities to Avoid（教育性说明）
            Section("Capabilities to avoid") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The on-device model is not suitable for:")
                        .font(.subheadline.weight(.semibold))
                    Text("• Basic counting / exact math (e.g. “How many b’s are there in ‘bagel’?”)")
                    Text("• Code generation (e.g. “Generate a Swift navigation list.”)")
                    Text("• Complex logical reasoning (e.g. “If I'm at Apple Park facing Canada, what direction is Texas?”)")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Foundation Model Demo")
        .onAppear {
            prompt = selectedCapability.examplePrompt
            inputText = selectedInputPreset.sampleText
        }
    }
    
    // MARK: - Helpers
    
    private var isModelAvailable: Bool {
        if case .available = systemModel.availability {
            return true
        }
        return false
    }
    
    private func runGeneration() async {
        guard isModelAvailable else {
            errorMessage = "System model is unavailable. Please turn on Apple Intelligence or use fallback."
            return
        }
        
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInput  = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 至少要有 Prompt 或识别文本之一
        guard !trimmedPrompt.isEmpty || !trimmedInput.isEmpty else {
            errorMessage = "Prompt 和识别文本都为空，请至少填写一项。"
            return
        }
        
        // 组合最终发送给模型的用户输入（Apple 文档推荐的包裹方式）
        let finalUserPrompt: String
        switch (trimmedPrompt.isEmpty, trimmedInput.isEmpty) {
        case (false, true):
            finalUserPrompt = trimmedPrompt
        case (true, false):
            finalUserPrompt = """
            Please analyze the following text:

            \(trimmedInput)
            """
        case (false, false):
            finalUserPrompt = """
            \(trimmedPrompt)

            ---
            Text to analyze:
            \(trimmedInput)
            """
        case (true, true):
            finalUserPrompt = ""
        }
        
        errorMessage = nil
        outputText = ""
        isGenerating = true
        lastUserPrompt = finalUserPrompt
        
        do {
            // 1. 拿到当前 Session（复用 or 新建）
            let currentSession: LanguageModelSession
            if reuseSession, let existing = session {
                currentSession = existing
            } else {
                // ✅ 这里真实使用了 Instructions { … } 的 DSL
                let instructionsObject = currentInstructionTemplate.makeInstructions()
                
                let newSession = LanguageModelSession(
                    instructions: instructionsObject
                )
                
                if reuseSession {
                    session = newSession
                } else {
                    session = nil
                }
                
                currentSession = newSession
            }
            
            // 2. 防止并发请求
            guard !currentSession.isResponding else {
                errorMessage = "Session is already responding. Wait for the previous request to finish."
                isGenerating = false
                return
            }
            
            // 3. GenerationOptions
            let options = GenerationOptions(temperature: temperature)
            
            // 4. 真正调用模型
            let response = try await currentSession.respond(
                to: finalUserPrompt,
                options: options
            )
            
            outputText = response.content
        } catch let genError as LanguageModelSession.GenerationError {
            // 对齐 Apple 文档的安全相关错误处理
            switch genError {
            case .exceededContextWindowSize(let size):
                errorMessage = "Exceeded context window size (\(size) tokens). Try shorter instructions/prompts or start a new session."
                
            case .guardrailViolation:
                // Guardrails 认为输入或输出不安全
                errorMessage = "Request was blocked by system guardrails. The input or output may contain sensitive content. Try rephrasing or narrowing the task."
                
            case .refusal(let refusal, _):
                // 模型拒绝任务，尝试拿解释信息
                if let explanation = try? await refusal.explanation {
                    errorMessage = explanation.content
                } else {
                    errorMessage = "The model refused to answer this request."
                }
                
            default:
                errorMessage = "Generation error: \(genError.localizedDescription)"
            }
        } catch {
            errorMessage = "Failed to generate: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
}

struct AvailabilityRow: View {
    let availability: SystemLanguageModel.Availability
    
    var body: some View {
        HStack {
            switch availability {
            case .available:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("On-device model is available.")
            case .unavailable(.deviceNotEligible):
                Image(systemName: "xmark.octagon.fill")
                    .foregroundColor(.red)
                Text("Device is not eligible for Apple Intelligence.")
            case .unavailable(.appleIntelligenceNotEnabled):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("Turn on Apple Intelligence in Settings.")
            case .unavailable(.modelNotReady):
                Image(systemName: "hourglass")
                    .foregroundColor(.orange)
                Text("Model is downloading or not ready yet.")
            case .unavailable(let other):
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
                Text("Model unavailable: \(String(describing: other))")
            }
        }
        .font(.footnote)
    }
}
