import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct AttachmentAIGenerateView: View {
    
    // MARK: - AI 引擎
    @StateObject private var engine = AIEngine()
    
    // MARK: - 文档 / 分页状态
    
    @State private var document: AttachmentDocument?
    @State private var pages: [AttachmentPage] = []
    @State private var scope: AIAttachmentScope = .wholeDocument
    @State private var selectedPage: AttachmentPage?
    
    // MARK: - UI State
    
    @State private var isFileImporterPresented = false
    @State private var attachmentName: String?
    @State private var attachmentText: String = ""   // 当前编辑 / 显示的文本
    
    @State private var aiOutput: String = ""
    @State private var isRunning: Bool = false
    @State private var currentActionTitle: String?
    @State private var errorMessage: String?
    
    // 文本加载器（actor）
    private let textLoader = AttachmentTextLoader()
    
    var body: some View {
        Form {
            // MARK: - 附件上传区
            
            Section("Attachment") {
                Button {
                    isFileImporterPresented = true
                } label: {
                    HStack {
                        Image(systemName: "tray.and.arrow.up")
                        Text(attachmentName ?? "上传 / 选择一个文本文件 / PDF / 图片")
                    }
                }
                
                // 范围选择：整份文档 / 按页
                if document != nil {
                    Picker("处理范围", selection: $scope) {
                        ForEach(AIAttachmentScope.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 按页模式时，展示页列表
                if scope == .singlePage, !pages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(pages) { page in
                                Button {
                                    selectedPage = page
                                    attachmentText = page.text
                                } label: {
                                    Text(page.title)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            selectedPage == page ?
                                            Color.accentColor.opacity(0.15) :
                                            Color.secondary.opacity(0.1)
                                        )
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
                
                if !attachmentText.isEmpty {
                    TextEditor(text: $attachmentText)
                        .frame(minHeight: 150)
                        .font(.system(.body, design: .monospaced))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                        .padding(.top, 4)
                } else {
                    Text("还没有内容，可以先上传文件，或者直接在这里粘贴传真/文档的文本。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            
            // MARK: - AI 能力入口
            
            Section("AI Attachment Capabilities") {
                capabilityButton(
                    title: "✅ 自动检查是否填写完整",
                    subtitle: "检查缺失字段 / 不一致信息",
                    actionType: .completenessCheck
                )
                
                capabilityButton(
                    title: "🏷 文档自动标题生成",
                    subtitle: "如“2025税务申报 W-2”",
                    actionType: .titleGeneration
                )
                
                capabilityButton(
                    title: "📄 生成 Fax 封面说明",
                    subtitle: "自动生成封面备注 & 说明",
                    actionType: .faxCoverNote
                )
                
                capabilityButton(
                    title: "🧾 总结传真内容并生成发送理由",
                    subtitle: "解释“为什么要发这份传真”",
                    actionType: .summaryWithReason
                )
                
                capabilityButton(
                    title: "✏️ AI 文本纠正 / 优化",
                    subtitle: "语法、拼写、表达优化",
                    actionType: .textCorrection
                )
            }
            
            // MARK: - AI 输出
            
            Section("AI 输出") {
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }
                
                if isRunning, let title = currentActionTitle {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("正在执行：\(title)")
                    }
                }
                
                if !aiOutput.isEmpty {
                    Text(aiOutput)
                        .font(.system(.body, design: .default))
                        .textSelection(.enabled)
                } else if !isRunning {
                    Text("点击上面的任意 AI 按钮，结果会显示在这里。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Attachment AI Demo")
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.plainText, .pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .task {
            engine.checkAvailability()
        }
    }
    
    // MARK: - UI 子视图
    
    private func capabilityButton(
        title: String,
        subtitle: String,
        actionType: AttachmentAITask
    ) -> some View {
        Button {
            runTask(actionType)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(attachmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunning)
    }
    
    // MARK: - 文件导入（只负责权限 + 调用 Loader）
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            attachmentName = url.lastPathComponent
            errorMessage = nil
            attachmentText = ""
            document = nil
            pages = []
            selectedPage = nil
            
            Task {
                // security-scoped 访问
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "没有权限访问该文件。"
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                do {
                    let doc = try await textLoader.loadDocument(from: url, name: attachmentName)
                    // 更新 UI 状态（main actor 上）
                    document = doc
                    pages = doc.pages
                    scope = pages.count > 1 ? .wholeDocument : .singlePage
                    selectedPage = pages.first
                    attachmentText = scope == .wholeDocument ? doc.fullText : (pages.first?.text ?? "")
                } catch {
                    errorMessage = "解析文件失败：\(error.localizedDescription)"
                }
            }
            
        case .failure(let error):
            errorMessage = "选择文件失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: - 执行 AI 任务（整文档 / 分页）
    
    private func runTask(_ task: AttachmentAITask) {
        errorMessage = nil
        aiOutput = ""
        
        let trimmed = attachmentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请先上传或输入文档内容。"
            return
        }
        
        isRunning = true
        currentActionTitle = task.title + (scope == .singlePage && selectedPage != nil ? "（\(selectedPage!.title)）" : "")
        
        let prompt = task.buildPrompt(from: trimmed)
        
        Task {
            do {
                let stream = engine.generateResponse(for: prompt)
                for try await chunk in stream {
                    aiOutput.append(chunk)
                }
            } catch {
                errorMessage = "AI 处理失败：\(error.localizedDescription)"
            }
            isRunning = false
        }
    }
}

private enum AttachmentAITask {
    case completenessCheck
    case titleGeneration
    case faxCoverNote
    case summaryWithReason
    case textCorrection
    
    var title: String {
        switch self {
        case .completenessCheck:
            return "自动检查是否填写完整"
        case .titleGeneration:
            return "文档自动标题生成"
        case .faxCoverNote:
            return "生成 Fax 封面说明"
        case .summaryWithReason:
            return "总结 + 发送理由"
        case .textCorrection:
            return "AI 文本纠正"
        }
    }
    
    func buildPrompt(from content: String) -> String {
        switch self {
        case .completenessCheck:
            return """
            你是一个文档校验助手。请根据以下文本内容，判断用户是否已经填写完整所有必要信息：
            1. 列出明显缺失的字段（例如缺少签名、日期、地址、社保号等）。
            2. 列出逻辑上不一致或可疑的地方（比如日期前后矛盾）。
            3. 最后用一句话总结：“该文档填写完整”或“不完整，需要补充：xxx”。

            文本内容：
            \(content)
            """
            
        case .titleGeneration:
            return """
            根据以下文档内容，生成一个简短且清晰的标题。风格类似：
            - “2025税务申报 W-2”
            - “医疗报销申请表”
            - “公司入职体检报告”

            要求：
            - 用中文输出一个标题。
            - 不要加引号，不要额外解释。

            文本内容：
            \(content)
            """
            
        case .faxCoverNote:
            return """
            请为下面这份传真内容生成一段英文 fax cover note，包含：
            - Subject（主题，简短）
            - Brief message（2-4 句，说明这份传真包含什么、对方需要做什么）

            用英文输出，格式示例：
            Subject: ...
            Message:
            ...

            Fax 内容：
            \(content)
            """
            
        case .summaryWithReason:
            return """
            请先用 2-3 句话总结以下传真或文档的主要内容，然后再用 1 句话说明：
            “我为什么要把这份传真发送给对方”（例如“因此我将此传真发送给 IRS 用于 2025 年度报税资料补充”）。

            输出格式：
            摘要：...
            发送理由：...

            文本内容：
            \(content)
            """
            
        case .textCorrection:
            return """
            请在不改变原始含义的前提下，纠正下面文本中的语法、拼写和表达问题，并输出一份更自然、更专业的版本。

            只输出修改后的文本，不要解释修改过程。

            原文：
            \(content)
            """
        }
    }
}
