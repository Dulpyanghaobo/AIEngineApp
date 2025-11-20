import SwiftUI

struct AIWritingAssistantTextEditor: View {
    @Binding var text: String
    
    @StateObject private var aiEngine = AIEngine()
    
    @FocusState private var isFocused: Bool
    @State private var isMenuPresented = false

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var pendingAction: AIWritingActionKind?

    // 新增：二级列表 & Analyze Sheet
    @State private var showTonePicker = false
    @State private var showLanguagePicker = false
    @State private var showAnalyzeSheet = false
    
    var body: some View {
        VStack {
            TextEditor(text: $text)
                .focused($isFocused)
                .disabled(isLoading)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .opacity(isLoading ? 0.7 : 1.0)
        }
        .toolbar {
            // ① 占据整行，按钮在右侧
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    isMenuPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Writing Assistant")
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
                .disabled(isLoading)
            }
        }
        .sheet(isPresented: $isMenuPresented) {
            assistantMenuSheet
        }
        .sheet(isPresented: $showTonePicker) {
            tonePickerSheet
        }
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
        }
        .sheet(isPresented: $showAnalyzeSheet) {
            analyzeSheet
        }
        .overlay(alignment: .bottomTrailing) {
            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .onAppear {
            aiEngine.checkAvailability()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }
    
    private var assistantMenuSheet: some View {
        NavigationStack {
            List {
                Section("Writing tools") {
                    ForEach(AIWritingActionKind.menuGroups[0], id: \.id) { kind in
                        menuRow(for: kind)
                    }
                }
                
                Section("More options") {
                    ForEach(AIWritingActionKind.menuGroups[1], id: \.id) { kind in
                        menuRow(for: kind)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .disabled(isLoading)
            .navigationTitle("Writing Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        isMenuPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            isFocused = true
                        }
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.5), .large])
        .presentationDragIndicator(.visible)
    }

    private func menuRow(for kind: AIWritingActionKind) -> some View {
        Button {
            handleMenuSelection(kind)
        } label: {
            HStack {
                Image(systemName: kind.symbolName)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.system(size: 16, weight: .semibold))
                    Text(kind.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }.foregroundStyle(.black)
        }
        .disabled(isLoading)
    }
    
    private func handleMenuSelection(_ kind: AIWritingActionKind) {
        switch kind {
        case .changeTone:
            // 关闭主菜单 -> 打开 tone picker
            isMenuPresented = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showTonePicker = true
            }
            
        case .translate:
            isMenuPresented = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showLanguagePicker = true
            }
            
        case .analyzeText:
            isMenuPresented = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showAnalyzeSheet = true
            }
            
        default:
            apply(kind, dismissMenuWhenDone: true)
        }
    }

    private var tonePickerSheet: some View {
        NavigationStack {
            List(ChangeToneOption.allCases) { option in
                Button {
                    showTonePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        apply(.changeTone, tone: option, dismissMenuWhenDone: false)
                    }
                } label: {
                    Text(option.title)
                }
            }
            .navigationTitle("Change Tone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { showTonePicker = false }
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium])
    }

    // MARK: - Language picker

    private var languagePickerSheet: some View {
        NavigationStack {
            List(TranslateLanguageOption.allCases) { option in
                Button {
                    showLanguagePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        apply(.translate, targetLanguage: option, dismissMenuWhenDone: false)
                    }
                } label: {
                    Text(option.displayName)
                }
            }
            .navigationTitle("Translate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { showLanguagePicker = false }
                }
            }
        }
        .presentationDetents([.fraction(0.4), .medium])
    }
    
    private var analyzeSheet: some View {
        WAAnalyzeSheet(
            originalText: text,
            analyzeAction: { _ in        // 👈 不用参数
                let input = text         // 👈 直接从绑定拿当前文本
                
                // 防御性保护：如果这一步有问题直接返回空结果，避免模型调用
                guard !input.isEmpty else { return [] }
                print("Analyze input length:", input.count)
                print("Analyze input preview:", input.prefix(120))
                
                // 使用 Apple FM 结构化生成
                let prompt = """
                You are an expert writing assistant.

                Analyze the following user text. 
                - Identify sentences that could be improved for clarity, conciseness, tone, or professionalism.
                - For each sentence that should be improved, provide:
                  1) originalSentence: the original sentence text.
                  2) suggestedSentence: a revised version that keeps the original meaning.

                Focus on sentences, not single words. If the text is already good, return an empty list.

                User text:
                \(input)
                """
                
                let result: AnalyzeResultModel = try await aiEngine.generateOnce(
                    structuredResponseFor: prompt,
                    of: AnalyzeResultModel.self
                )
                
                return result.suggestions.map {
                    WAAnalyzeSuggestion(
                        originalSentence: $0.originalSentence,
                        suggestedSentence: $0.suggestedSentence
                    )
                }
            },
            onFinish: { newText in
                text = newText
            }
        )
    }
    
    private func quickChip(for kind: AIWritingActionKind) -> some View {
        Button {
            apply(kind, dismissMenuWhenDone: false)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: kind.symbolName)
                Text(kind.title)
                    .lineLimit(1)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
        .disabled(isLoading || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    private func apply(_ action: AIWritingActionKind,
                       tone: ChangeToneOption? = nil,
                       targetLanguage: TranslateLanguageOption? = nil,
                       dismissMenuWhenDone: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isFocused = false
        isLoading = true
        errorMessage = nil
        
        let original = text
        let prompt = buildPrompt(
            for: action,
            input: original,
            tone: tone,
            targetLanguage: targetLanguage
        )
        
        Task {
            do {
                var newText = ""
                let stream = aiEngine.generateResponse(for: prompt)
                
                for try await token in stream {
                    newText.append(token)
                }
                
                if !newText.isEmpty {
                    text = newText
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
            
            if dismissMenuWhenDone {
                isMenuPresented = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
    
    private func buildPrompt(
        for action: AIWritingActionKind,
        input: String,
        tone: ChangeToneOption? = nil,
        targetLanguage: TranslateLanguageOption? = nil
    ) -> String {
        let safeInput = input.replacingOccurrences(of: "`", with: "\\`")
        
        let baseIntro = """
        You are an on-device Apple intelligence language model that helps with professional writing tasks.

        Always return ONLY the final resulting text.
        Do not include explanations, labels, or JSON.
        Preserve markdown / HTML / whitespace formatting as much as possible.
        """
        
        let actionInstruction: String
        
        switch action {
        case .enhanceWriting:
            actionInstruction = """
            TASK: Enhance Writing
            - Improve grammar, spelling, clarity, flow and vocabulary.
            - Keep the original meaning and general tone.
            """
            
        case .changeTone:
            if let tone = tone {
                actionInstruction = """
                TASK: Change Tone
                - \(tone.promptInstruction)
                - Do NOT change factual content or meaning.
                """
            } else {
                actionInstruction = """
                TASK: Change Tone
                - Make the text more suitable for polite business communication.
                - Adjust to a balanced professional and friendly tone.
                - Do NOT change factual content or meaning.
                """
            }
            
        case .makeShorter:
            actionInstruction = """
            TASK: Make Shorter
            - Rewrite the text to be more concise and direct.
            - Remove redundancy while preserving key information and intent.
            """
            
        case .makeLonger:
            actionInstruction = """
            TASK: Make Longer
            - Expand the text with more detail, examples and context.
            - Keep the original intent and structure.
            """
            
        case .makeBulletedList:
            actionInstruction = """
            TASK: Make Bulleted List
            - Convert the text into a clear bulleted list.
            - Use short bullet items, each describing one idea.
            """
            
        case .analyzeText:
            actionInstruction = """
            TASK: Rewrite after Analysis
            - Improve clarity, conciseness and tone based on your best judgement.
            - Make the text neutral, inclusive and non-discriminatory.
            - Remove or rephrase biased or harmful expressions if any.
            - Keep the original informational content.
            """
            
        case .translate:
            let target = targetLanguage?.targetDescription ?? "American English"
            actionInstruction = """
            TASK: Translate
            - Detect the input language and translate it into \(target).
            - Preserve tone and level of formality.
            - The output must be only in \(target).
            """
        }
        
        return """
        \(baseIntro)

        \(actionInstruction)

        USER TEXT:
        ```
        \(safeInput)
        ```
        """
    }
}
