import SwiftUI
import FoundationModels

// MARK: - 练习模式 ---------------------------------------------------

enum PromptPracticeMode: String, CaseIterable, Identifiable {
    case qa        // 问答助手
    case rewrite   // 文本改写
    case idea      // 创意点子
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .qa:      return "QA Helper"
        case .rewrite: return "Rewrite"
        case .idea:    return "Idea Generator"
        }
    }
}

/// 如果你已经有 ProductIdea，可以直接复用；
// 这里给一个精简版，避免依赖其他文件。
struct PracticeProductIdea: PromptRepresentable {
    let title: String
    let description: String
    
    var promptRepresentation: Prompt {
        """
        Product Idea:
        - Title: \(title)
        - Description: \(description)
        """
    }
}

@MainActor
struct PromptBuilderPracticeView: View {
    
    // 练习模式 & 输入
    @State private var mode: PromptPracticeMode = .qa
    @State private var userQuestion: String = "Help me grow my Fax app installs."
    
    // PromptBuilder 控制开关（对应文档里的各种 buildX 特性）
    @State private var addShortAnswer: Bool = true
    @State private var addFriendlyTone: Bool = true
    @State private var addJsonOutput: Bool = false
    @State private var addRhyming: Bool = false   // 对应 Apple 示例中的 responseShouldRhyme
    
    // 输出 & 状态
    @State private var isGenerating: Bool = false
    @State private var outputText: String = ""
    @State private var errorMessage: String?
    
    // Debug：用 String 展示 Prompt 的最终文本（不是从 Prompt 里面读，而是自己拼）
    @State private var promptPreviewText: String = ""
    
    var body: some View {
        Form {
            // MARK: - 小练习说明
            Section("练习说明") {
                Text("""
                     1️⃣ 在下面输入一个问题。
                     2️⃣ 打开 / 关闭不同开关，观察右侧 Prompt Preview 如何变化。
                     3️⃣ 点击 Generate，看看不同 Prompt 对模型输出有什么影响。
                     """)
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            // MARK: - 模式 & 输入
            Section("Mode & Input") {
                Picker("Practice Mode", selection: $mode) {
                    ForEach(PromptPracticeMode.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                
                TextEditor(text: $userQuestion)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )
                
                Text("""
                     This text simulates the user's input. \
                     It will be wrapped inside your prompt instead of being sent raw.
                     """)
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            // MARK: - PromptBuilder 练习选项
            Section("PromptBuilder Options") {
                Toggle("Short answer (<= 3 sentences)", isOn: $addShortAnswer)
                Toggle("Friendly & encouraging tone", isOn: $addFriendlyTone)
                Toggle("Return structured JSON output", isOn: $addJsonOutput)
                Toggle("Response MUST rhyme", isOn: $addRhyming)   // 对应 Apple 示例
            }
            
            // MARK: - Prompt Preview
            Section("Prompt Preview (built by PromptBuilder)") {
                if promptPreviewText.isEmpty {
                    Text("Tap Generate to build and preview the prompt.")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                } else {
                    ScrollView {
                        Text(promptPreviewText)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 120)
                }
                
                Text("""
                     Internally this uses:
                     Prompt { ... }
                     with if-conditions and a for-loop over [String] \
                     (triggering PromptBuilder.buildArray(_:)).
                     """)
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            // MARK: - Run
            Section("Run") {
                Button {
                    Task { await runGeneration() }
                } label: {
                    HStack {
                        if isGenerating { ProgressView() }
                        Text(isGenerating ? "Generating…" : "Generate with PromptBuilder")
                    }
                }
                .disabled(isGenerating)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            
            // MARK: - Output
            Section("Model Output") {
                if outputText.isEmpty {
                    Text("Model response will appear here.")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                } else {
                    ScrollView {
                        Text(outputText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 150)
                }
            }
        }
        .navigationTitle("PromptBuilder 练习")
    }
    
    // MARK: - 核心：用同一套逻辑构建 lines & Prompt ----------------------
    
    /// 把 PromptBuilder 里的内容先“抽象成”一组 String，既好预览，也方便构造 Prompt。
    private func buildPromptLines() -> [String] {
        var lines: [String] = []
        
        // 1. 根据模式设置主任务句
        switch mode {
        case .qa:
            lines.append("Answer the following question from the user.")
        case .rewrite:
            lines.append("Rewrite the user's text to make it clearer and more concise.")
        case .idea:
            lines.append("Generate a product idea inspired by the user's text.")
            // 用 PromptRepresentable 的结构化类型（类似文档中的 FamousHistoricalFigure）
            let idea = PracticeProductIdea(
                title: "Jet AI Scanner",
                description: "An AI-powered document scanner for fax and PDF workflows."
            )
            // 这里只是为了在 preview 里看到结构化线索，简单用一行描述
            lines.append("Context: \(idea.title) – \(idea.description)")
        }
        
        let trimmed = userQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            lines.append("---")
            lines.append("User input:")
            lines.append(trimmed)
        }
        
        if addShortAnswer {
            lines.append("Answer in 3 sentences or fewer.")
        }
        if addFriendlyTone {
            lines.append("Use a friendly and encouraging tone.")
        }
        if addJsonOutput {
            lines.append("Return your answer as valid JSON with fields 'answer' and 'tags'.")
        }
        if addRhyming {
            // 完全对应 Apple 文档的 example
            lines.append("Your response MUST rhyme!")
        }
        
        return lines
    }
    
    /// 用 PromptBuilder 把这些 lines 变成 Prompt
    private func makePrompt() -> Prompt {
        let lines = buildPromptLines()
        
        // 这里的 for line in lines 会触发 PromptBuilder.buildArray(_:)
        let prompt = Prompt {
            
            for line in lines {
                line
            }
        }
        
        // 同时更新 preview 文本，方便开发者查看
        promptPreviewText = lines.joined(separator: "\n")
        
        return prompt
    }
    
    // MARK: - 调用模型
    private func runGeneration() async {
        isGenerating = true
        outputText = ""
        errorMessage = nil
        
        let promptObject = makePrompt()
        
        do {
            let session = LanguageModelSession()
            // 直接把 Prompt 作为参数传给 respond
            let response = try await session.respond(to: promptObject)
            outputText = response.content
        } catch {
            errorMessage = "Generation error: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
}
