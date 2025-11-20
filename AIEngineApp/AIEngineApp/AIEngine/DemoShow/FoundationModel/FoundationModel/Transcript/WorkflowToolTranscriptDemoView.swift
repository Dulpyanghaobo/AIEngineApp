import SwiftUI
import UniformTypeIdentifiers
import Foundation
import FoundationModels
import PDFKit

struct WorkflowToolTranscriptDemoView: View {

    // MARK: - Document state ------------------------------------------------

    @State private var isFileImporterPresented = false
    @State private var currentDocumentURL: URL?
    @State private var currentDocumentInfoText: String = "尚未选择文档"
    
    // MARK: - LM session & transcript --------------------------------------

    @State private var session: LanguageModelSession?
    @State private var transcript: Transcript = Transcript()
    
    @State private var userInput: String = ""
    @State private var isRunning: Bool = false
    @State private var lastResponseText: String = ""
    @State private var errorMessage: String?

    private let systemModel = SystemLanguageModel.default

    var body: some View {
        NavigationStack {
            Form {
                // 1. 上传 / 选择文档
                Section("1. 上传要处理的文档") {
                    Button {
                        isFileImporterPresented = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("从文件中选择 PDF / 图片")
                        }
                    }

                    Text(currentDocumentInfoText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 2. 用户自然语言指令
                Section("2. 和 AI 讨论这个文档（模型可以多次调用工具）") {
                    TextEditor(text: $userInput)
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2))
                        )
                        .disabled(session == nil)

                    if session == nil {
                        Text("请先上传一份文档，系统会为该文档创建一个带 Tool 的 LanguageModelSession。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        Task { await runWorkflowConversation() }
                    } label: {
                        HStack {
                            if isRunning { ProgressView() }
                            Text("发送给 on-device 模型（允许多次 Tool 调用）")
                        }
                    }
                    .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session == nil || isRunning)
                }

                // 3. 模型回答
                if !lastResponseText.isEmpty {
                    Section("模型最终回答") {
                        ScrollView {
                            Text(lastResponseText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 80)
                    }
                }

                // 4. Transcript 可视化
                Section("3. Transcript - 整个多轮调用过程") {
                    if session == nil {
                        Text("创建会话后，这里会展示 Instructions / Prompt / ToolCalls / ToolOutput / Response 的完整历史。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(transcript), id: \.id) { entry in
                                    transcriptRow(for: entry)
                                        .padding(6)
                                        .background(Color.gray.opacity(0.06))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .frame(minHeight: 200)
                    }
                }

                if let msg = errorMessage {
                    Section("Error") {
                        Text(msg)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Workflow + Tools + Transcript")
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = "选择文件失败：\(error.localizedDescription)"

        case .success(let urls):
            guard let pickedURL = urls.first else { return }

            // 1. 申请 security-scoped 访问权限
            var sandboxURL = pickedURL
            let fm = FileManager.default

            if pickedURL.startAccessingSecurityScopedResource() {
                defer { pickedURL.stopAccessingSecurityScopedResource() }

                do {
                    // 2. 拷贝到自己 App 的临时目录
                    let destURL = fm.temporaryDirectory
                        .appendingPathComponent("workflow-\(UUID().uuidString)-\(pickedURL.lastPathComponent)")

                    // 如果已存在就删掉
                    if fm.fileExists(atPath: destURL.path) {
                        try fm.removeItem(at: destURL)
                    }
                    try fm.copyItem(at: pickedURL, to: destURL)
                    sandboxURL = destURL
                } catch {
                    errorMessage = "复制文件到沙盒失败：\(error.localizedDescription)"
                    return
                }
            } else {
                // 理论上不会太常见，这里兜底提示一下
                errorMessage = "无法访问所选文件的安全作用域。"
                return
            }

            // 3. 之后系统内所有 Tool / PDFKit / OCR 都只用 sandboxURL
            self.currentDocumentURL = sandboxURL
            self.errorMessage = nil
            self.lastResponseText = ""

            // 展示基础信息（用沙盒路径）
            var infoLines: [String] = []
            infoLines.append("文件：\(sandboxURL.lastPathComponent)")
            let ext = sandboxURL.pathExtension.lowercased()
            infoLines.append("类型：\(ext.isEmpty ? "unknown" : ext)")
            if let sizeBytes = try? sandboxURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                let mb = Double(sizeBytes) / (1024.0 * 1024.0)
                infoLines.append(String(format: "大小：%.2f MB", mb))
            }
            self.currentDocumentInfoText = infoLines.joined(separator: " · ")

            // 4. 用沙盒 URL 重建带工具的 session
            Task {
                await buildSession(for: sandboxURL)
            }
        }
    }


    private func buildSession(for url: URL) async {
        // 工具：与当前文档强绑定的两个 + 你之前的工具
        let docInfoTool  = CurrentDocumentInfoTool(documentURL: url)
        let ocrTool      = CurrentDocumentOCRTool(documentURL: url)
        let compressTool = CompressPDFSimulationTool()          // 模拟压缩大小
        let faxTool      = FaxQuoteTool(
            pricing: .init(
                freePages: 50,
                domesticPerPageCredits: 1,
                intlPerPageCredits: 2
            )
        )
        let coverTool    = GenerateFaxCoverPageTool()

        let tools: [any Tool] = [
            docInfoTool,
            ocrTool,
            compressTool,
            faxTool,
            coverTool
        ]

        // Instructions：告诉模型如何 orchestrate 这些工具做「workflow」
        let instructions = Instructions {
            "You are a Fax & Scan workflow assistant."
            "The user has uploaded ONE current document (PDF or image). You have tools that operate on this current document."
            "When the user asks about file size, page count, or basic info, call 'getCurrentDocumentInfo'."
            "When the user asks to extract content, key fields, or to understand what is inside the document, call 'ocrCurrentDocument' first."
            "If the user cares about compression or final file size, first call 'getCurrentDocumentInfo', then call 'simulatePDFCompression' using the returned fileSizeMB, and explain the effect."
            "If the user wants to send a fax of this document, use 'estimateFaxQuote' to estimate page credits and cost, then use 'generateFaxCoverPage' if they mention a recipient/sender."
            "You MAY call multiple tools in one turn to achieve a small workflow, e.g. first get info, then OCR, then estimate fax cost, then generate a cover page."
            "Always answer in the same language as the user (often Chinese), and clearly explain what tools you used."
        }

        let newSession = LanguageModelSession(
            model: systemModel,
            tools: tools,
            instructions: instructions
        )

        await MainActor.run {
            self.session = newSession
            self.transcript = newSession.transcript
        }
    }

    // MARK: - Run conversation with tools ----------------------------------

    private func runWorkflowConversation() async {
        guard let session else {
            errorMessage = "请先上传一份文档，系统会为该文档创建会话。"
            return
        }

        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await MainActor.run {
            isRunning = true
            errorMessage = nil
        }

        do {
            var options = GenerationOptions()
            options.maximumResponseTokens = 200
            options.sampling = .greedy
            options.temperature = 0
            // 让模型自动决定是否 / 如何调用工具
            let response = try await session.respond(to: trimmed, options: options)

            let text = response.content

            await MainActor.run {
                self.lastResponseText = text
                self.userInput = ""
                self.transcript = session.transcript
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to generate: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isRunning = false
        }
    }

    // MARK: - Transcript rendering helpers ---------------------------------

    @ViewBuilder
    private func transcriptRow(for entry: Transcript.Entry) -> some View {
        switch entry {
        case .instructions(let inst):
            VStack(alignment: .leading, spacing: 4) {
                Text("📘 Instructions")
                    .font(.caption.bold())
                Text(joinedText(from: inst.segments))
                    .font(.caption)
            }

        case .prompt(let prompt):
            VStack(alignment: .leading, spacing: 4) {
                Text("🧑‍💻 Prompt")
                    .font(.caption.bold())
                Text(joinedText(from: prompt.segments))
                    .font(.caption)
            }

        case .toolCalls(let calls):
            VStack(alignment: .leading, spacing: 4) {
                Text("🛠 Tool Calls")
                    .font(.caption.bold())
                ForEach(Array(calls), id: \.id) { call in
                    Text("• \(call.toolName) – args: \(String(describing: call.arguments))")
                        .font(.caption2)
                }
            }

        case .toolOutput(let output):
            VStack(alignment: .leading, spacing: 4) {
                Text("📤 Tool Output (\(output.toolName))")
                    .font(.caption.bold())
                Text(joinedText(from: output.segments))
                    .font(.caption2)
            }

        case .response(let resp):
            VStack(alignment: .leading, spacing: 4) {
                Text("🤖 Response")
                    .font(.caption.bold())
                Text(joinedText(from: resp.segments))
                    .font(.caption)
            }
        }
    }

    private func joinedText(from segments: [Transcript.Segment]) -> String {
        segments.compactMap { seg in
            if case let .text(textSeg) = seg {
                return textSeg.content
            } else {
                return nil
            }
        }
        .joined()
    }
}
