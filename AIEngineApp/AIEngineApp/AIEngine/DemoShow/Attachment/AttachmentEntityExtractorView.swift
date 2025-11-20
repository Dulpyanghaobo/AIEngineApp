import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct AttachmentEntityExtractorView: View {
    // MARK: - AI 引擎（结构化实体抽取）
    @StateObject private var aiEngine = AIEngine(configuration: .contentTagger)
    @FocusState private var isTextEditorFocused: Bool

    // MARK: - 文档 / 分页状态
    @State private var document: AttachmentDocument?
    @State private var pages: [AttachmentPage] = []
    @State private var scope: AIAttachmentScope = .wholeDocument
    @State private var selectedPage: AttachmentPage?

    // MARK: - 文件导入 / 文本
    @State private var isFileImporterPresented = false
    @State private var attachmentName: String?
    @State private var attachmentText: String = ""

    // MARK: - 抽取结果
    @State private var extractedEntities: FaxEntities?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    @State private var isParsingAttachment: Bool = false

    private let textLoader = AttachmentTextLoader()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: - 说明
                    Text("上传传真附件（文本 / PDF / 图片），或直接粘贴文本，使用本地 AI 自动抽取人名、地点、公司、日期和金额。")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // MARK: - 附件上传区
                    attachmentSection

                    // MARK: - 操作按钮
                    HStack(spacing: 12) {
                        Button {
                            // 示例文本一键填充
                            useExampleText()
                        } label: {
                            Label("Use Example", systemImage: "text.badge.plus")
                        }

                        Button(action: runExtraction) {
                            if isLoading {
                                ProgressView()
                            } else {
                                Label("Extract Entities", systemImage: "sparkles")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            isLoading ||
                            isParsingAttachment ||
                            attachmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                    // MARK: - 抽取结果
                    if let entities = extractedEntities {
                        resultSection(entities: entities)
                    }

                    if let errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundStyle(.red)
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Attachment Entity Extractor")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isTextEditorFocused = false }
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.plainText, .pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .onAppear { aiEngine.checkAvailability() }
        }
    }

    // MARK: - 附件上传 + 范围选择 + 文本编辑 UI

    @ViewBuilder
    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 上传按钮
            Button {
                isFileImporterPresented = true
            } label: {
                HStack {
                    Image(systemName: "tray.and.arrow.up")
                    Text(attachmentName ?? "上传 / 选择一个文本文件 / PDF / 图片")
                }
            }.disabled(isParsingAttachment || isLoading)


            // 范围选择：整份文档 / 按页
            if document != nil {
                Picker("处理范围", selection: $scope) {
                    ForEach(AIAttachmentScope.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 按页模式下的页签
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
                                        selectedPage == page
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.secondary.opacity(0.1)
                                    )
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }

            // 文本编辑区（无论是粘贴文本还是从附件解析来的文本，都在这里展示）
            TextEditor(text: $attachmentText)
                .frame(minHeight: 200)
                .border(Color.gray.opacity(0.2), width: 1)
                .cornerRadius(8)
                .focused($isTextEditorFocused)

            if isParsingAttachment {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在解析附件并进行 OCR 识别…")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            if document == nil && attachmentText.isEmpty {
                Text("还没有内容，可以先上传文件，或者直接在这里粘贴传真/文档的文本。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func resultSection(entities: FaxEntities) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fax Cover Metadata")
                .font(.headline)

            if scope == .singlePage, let page = selectedPage {
                Text("Scope: \(page.title)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Scope: 整份文档")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                FaxFieldRow(label: "Page count", value: entities.pageCount.map { "\($0)" })
                FaxFieldRow(label: "Fax date",   value: entities.faxDate)
                Divider()
                FaxFieldRow(label: "TO name",    value: entities.toName)
                FaxFieldRow(label: "TO phone",   value: entities.toPhone)
                Divider()
                FaxFieldRow(label: "FROM name",  value: entities.fromName)
                FaxFieldRow(label: "FROM phone", value: entities.fromPhone)
                FaxFieldRow(label: "FROM email", value: entities.fromEmail)
                Divider()
                FaxFieldRow(label: "Theme",      value: entities.theme)
                FaxFieldRow(label: "Notes",      value: entities.notes)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
        }
    }

    private struct FaxFieldRow: View {
        let label: String
        let value: String?

        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                Text(label + ":")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 90, alignment: .leading)
                Text(value?.isEmpty == false ? value! : "—")
                    .font(.subheadline)
                    .foregroundColor(value == nil || value?.isEmpty == true ? .secondary : .primary)
                Spacer()
            }
        }
    }

    // MARK: - 示例文本
    private func useExampleText() {
        isTextEditorFocused = false
        document = nil
        pages = []
        scope = .wholeDocument
        selectedPage = nil
        attachmentName = "Example.txt"
        extractedEntities = nil
        errorMessage = nil

        attachmentText =
        """
        ACME Health Clinic
        123 Market Street, San Francisco, CA 94105, USA

        Patient: John Doe
        Date: 10/25/2025
        Invoice Amount: $320.75

        Please send payment to ACME Health Clinic.
        """
    }

    // MARK: - 文件导入（只负责权限 + 调用 Loader）

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            attachmentName = url.lastPathComponent
            errorMessage = nil
            extractedEntities = nil
            attachmentText = ""
            document = nil
            pages = []
            selectedPage = nil

            Task {
                isParsingAttachment = true
                defer { isParsingAttachment = false }

                // security-scoped 访问
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "没有权限访问该文件。"
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let doc = try await textLoader.loadDocument(from: url, name: attachmentName)
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

    // MARK: - 调用 AI 进行实体抽取

    private func runExtraction() {
        isTextEditorFocused = false
        isLoading = true
        extractedEntities = nil
        errorMessage = nil

        // 如果是“整份文档”模式并且有分页，就逐页抽取 + 合并
        if scope == .wholeDocument,
           let doc = document,
           !pages.isEmpty {

            Task {
                var aggregated = FaxEntities()
                var hasAnyResult = false

                for page in pages.sorted(by: { $0.index < $1.index }) {
                    let trimmed = page.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }

                    let safeText = trimmed.replacingOccurrences(of: "`", with: "\\`")
                    let prompt = buildFaxEntitiesPrompt(from: safeText, pageIndex: page.index, totalPages: pages.count, docName: doc.name)

                    do {
                        let pageResult: FaxEntities = try await aiEngine.generateOnce(
                            structuredResponseFor: prompt,
                            of: FaxEntities.self
                        )
                        aggregated.merge(overridingWith: pageResult)
                        hasAnyResult = true
                    } catch {
                        // 某一页失败就跳过，继续后面的页
                        print("⚠️ Page \(page.index) extraction failed: \(error)")
                        continue
                    }
                }

                if hasAnyResult {
                    extractedEntities = aggregated
                } else {
                    errorMessage = "未能从任何页面中抽取到 Fax 封面信息。"
                }

                isLoading = false
            }

        } else {
            // 单页 / 手动粘贴文本：沿用原来的单次抽取逻辑
            let trimmed = attachmentText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                errorMessage = "请先上传或输入文档内容。"
                isLoading = false
                return
            }

            let safeText = trimmed.replacingOccurrences(of: "`", with: "\\`")
            let prompt = buildFaxEntitiesPrompt(from: safeText, pageIndex: selectedPage?.index, totalPages: pages.count, docName: document?.name)

            Task {
                do {
                    let result: FaxEntities = try await aiEngine.generateOnce(
                        structuredResponseFor: prompt,
                        of: FaxEntities.self
                    )
                    extractedEntities = result
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }
    /// 为 FaxEntities 抽取构建 Prompt，支持单页或多页场景
    private func buildFaxEntitiesPrompt(
        from text: String,
        pageIndex: Int?,
        totalPages: Int,
        docName: String?
    ) -> String {
        let pageInfo: String
        if let pageIndex {
            pageInfo = "This is page \(pageIndex) of a fax document with \(totalPages) pages (if known). Some fields may appear only on certain pages."
        } else {
            pageInfo = "This text may represent a fax cover or part of it."
        }

        let nameInfo = docName.map { "The file name is \"\($0)\"." } ?? ""

        return """
        You are an expert information extraction assistant specialized in fax cover sheets.

        CONTEXT:
        - \(pageInfo)
        - \(nameInfo)

        TASK:
        - Read the fax cover text provided between triple backticks.
        - Fill the FaxEntities structure with the following fields, using only information explicitly present in the text:

          1. pageCount:
             - The total number of pages in the fax.
             - For example, from "Page 14 pages" extract 14.
             - If you are not sure, use null.

          2. faxDate:
             - The date of the fax, such as "11/06/2025".
             - Keep the original formatting.

          3. toName:
             - The recipient's name in the TO section.
             - If the field is explicitly blank (like "—"), use null.

          4. toPhone:
             - The recipient's phone number in the TO section.

          5. fromName:
             - The sender's name in the FROM section.

          6. fromPhone:
             - The sender's phone number in the FROM section.

          7. fromEmail:
             - The sender's e-mail address in the FROM section, if present.

          8. theme:
             - The main theme or subject in the THEME section, e.g. "Loan #8200463906".

          9. notes:
             - The content of the NOTES section.
             - If the notes are blank (like "—"), use null or an empty string.

        RULES:
        - Only use information that appears in this page's text.
        - Do not invent or guess values.
        - If a field is missing or explicitly blank on this page, set it to null.
        - Return ONLY the FaxEntities structure. Do not add explanations or commentary.

        Fax text for this page:
        ```
        \(text)
        ```
        """
    }

}
