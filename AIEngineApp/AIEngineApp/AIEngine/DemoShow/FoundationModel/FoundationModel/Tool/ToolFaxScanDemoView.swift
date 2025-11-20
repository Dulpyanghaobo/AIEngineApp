//
//  FaxQuoteTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


import SwiftUI
import Foundation
import FoundationModels
import Contacts
import PhotosUI
import UIKit
// MARK: - Demo View：Tool + Model 集成 ------------------------------------

@MainActor
struct ToolFaxScanDemoView: View {
    
    enum Scenario: String, CaseIterable, Identifiable {
        case faxCost
        case scanPreset
        case lookupContact
        case recentFax
        case searchDocs
        case ocr
        case pdfPageCount
        case pdfCompress
        case faxCover
        case workflowSim

        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .faxCost:
                return "Fax cost / free pages"
            case .scanPreset:
                return "Scan preset suggestion"
            case .lookupContact:
                return "Lookup contact"
            case .recentFax:
                return "Recent fax status"
            case .searchDocs:
                return "Search scanned documents"
            case .ocr:
                return "Run OCR on image"
            case .pdfPageCount:
                return "Get PDF page count"
            case .pdfCompress:
                return "Simulate PDF compression"
            case .faxCover:
                return "Generate fax cover page"
            case .workflowSim:
                return "Simulate scan → OCR → fax workflow"
            }
        }
        
        var sampleUserPrompt: String {
            switch self {
            case .faxCost:
                return "我在美国，想给加拿大发一份 12 页、彩色的报税表传真。现在还有一些免费页，可以免费发完吗？请用中文解释一下。"
                
            case .scanPreset:
                return "我要在比较暗的房间里扫描一份多页的合同，主要是给税务局备份，既要清晰又不要太大，你推荐用什么扫描预设？"
                
            case .lookupContact:
                return "我想给 John 发一份传真，帮我在联系人里找一下名字里包含 John 的联系人，并帮我总结哪个最可能是他。"
                
            case .recentFax:
                return "我最近发了几份传真，总觉得有一份可能失败了。帮我查看最近三条传真记录的状态，并用中文帮我总结一下。"
                
            case .searchDocs:
                return "我想找一下所有和 tax 相关的扫描文件，帮我列出最近更新的几份文档，并说明各自的类型和修改时间。"
                
            case .ocr:
                return "我刚刚拍了一张报税表的照片，imageId 是 tax-photo-001。请先对这张图片执行 OCR，然后帮我用中文总结关键信息（例如姓名、收入、年份）。"
                
            case .pdfPageCount:
                return "有一个文件叫 Tax_2023.pdf，帮我看一下大概有多少页，并估算一下如果全部用黑白传真，需要消耗多少传真页数。"
                
            case .pdfCompress:
                return "现在有一个 8MB 的扫描 PDF，如果我选择中等压缩，大概会压到多少 MB？顺便帮我解释一下这种压缩级别适合用在什么场景。"
                
            case .faxCover:
                return "我要给 IRS 发送传真，发件人是 Hab Yang，收件人是 IRS Office Fax，主题是“2023 报税补交材料”。请帮我生成一份传真封面内容，并用中文说明封面上会包含哪些字段。"
                
            case .workflowSim:
                return "帮我模拟一个完整 workflow：我有一份多页合同，需要先扫描，再做 OCR，之后压缩成 PDF，最后发传真。请按步骤说明每一步大概会做什么、输出什么结果。"
            }
        }
    }

    private let systemModel = SystemLanguageModel.default
    
    // Tool 实例（带有当前“用户环境”的上下文）
    private let faxTool = FaxQuoteTool(
        pricing: .init(
            freePages: 50,               // 假设当前用户还有 50 credits
            domesticPerPageCredits: 1,
            intlPerPageCredits: 2
        )
    )
    private let scanTool = ScanPresetSuggestTool()
    private let lookupContactTool      = LookupContactTool()
    private let recentFaxTool          = RecentFaxStatusTool()
    private let documentSearchTool     = DocumentSearchTool()
    private let ocrTool                = OCRTool()
    private let pdfPageCountTool       = PDFPageCountTool()
    private let pdfCompressTool        = CompressPDFSimulationTool()
    private let faxCoverTool           = GenerateFaxCoverPageTool()
    private let workflowSimulateTool   = WorkflowSimulateTool()
    
    // UI State
    @State private var scenario: Scenario = .faxCost
    @State private var userPrompt: String = ""
    @State private var outputText: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?

    // MARK: - OCR 场景相关状态 ----------------------------
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedOCRImage: UIImage?
    @State private var ocrRawText: String = ""
    @State private var isRunningOCR: Bool = false
    @State private var ocrErrorMessage: String?
    
    var body: some View {
        Form {
            // 模型可用性
            Section("Model") {
                AvailabilityRow(availability: systemModel.availability)
            }
            
            // 场景选择
            Section("Scenario") {
                Picker("Demo Scenario", selection: $scenario) {
                    ForEach(Scenario.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                .onChange(of: scenario) { newValue in
                    userPrompt = newValue.sampleUserPrompt
                }
                
                Text("This demo shows how on-device tools can answer very app-specific questions for fax & scan.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 用户输入
            Section("User Prompt") {
                TextEditor(text: $userPrompt)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )
                
                Button("Use sample prompt") {
                    userPrompt = scenario.sampleUserPrompt
                }
                .font(.caption)
            }
            
            // 仅在 OCR 场景时显示图片上传与识别区域
            if scenario == .ocr {
                Section("Image for OCR") {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("从相册选择图片用于 OCR")
                        }
                    }

                    if let image = selectedOCRImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 150)
                            .cornerRadius(8)
                    }

                    if isRunningOCR {
                        HStack {
                            ProgressView()
                            Text("正在识别图片文字…")
                        }
                    }

                    if !ocrRawText.isEmpty {
                        Text("识别出的原始文本（会自动填入 Prompt）")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ScrollView {
                            Text(ocrRawText)
                                .font(.system(.footnote, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 80)
                    }

                    if let msg = ocrErrorMessage {
                        Text(msg)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            
            // 运行
            Section("Run with Tools") {
                Button {
                    Task { await runWithTools() }
                } label: {
                    HStack {
                        if isGenerating { ProgressView() }
                        Text(isGenerating ? "Generating…" : "Ask on-device model (with tools)")
                    }
                }
                .disabled(isGenerating || !isModelAvailable)
                
                if let err = errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                
                if !isModelAvailable {
                    Text("Model unavailable. Use your server-side fallback here.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            
            // 输出
            Section("Model Answer") {
                if outputText.isEmpty {
                    Text("The model's answer (after calling tools) will appear here.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        Text(outputText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 150)
                }
            }
            
            // 教程说明
            Section("How this demo maps to your app") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FaxQuoteTool:")
                        .font(.subheadline.weight(.semibold))
                    Text("• Use your real free-page balance & per-page pricing in PricingContext.")
                    Text("• Model learns to call this tool when user asks about cost/free fax.")
                    
                    Text("ScanPresetSuggestTool:")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 6)
                    Text("• Encode your real scan presets (dpi/filter/auto-crop) here.")
                    Text("• Model calls it when user asks 'which scan preset should I use?'.")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Tools: Fax & Scan")
        .onAppear {
            if userPrompt.isEmpty {
                userPrompt = scenario.sampleUserPrompt
            }
        }
        .onAppear {
            Task {
                let granted = await requestContactAccess()
                if !granted {
                    print("⚠️ Contacts permission not granted")
                }
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                await handleSelectedPhoto(newItem)
            }
        }
    }
    
    // MARK: - 处理相册选图 + 调用 OCRTool ----------------------------------
    private func handleSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        await MainActor.run {
            isRunningOCR = true
            ocrErrorMessage = nil
            ocrRawText = ""
        }

        do {
            // 1. 从 PhotosPickerItem 读取 Data → UIImage
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                throw NSError(
                    domain: "ToolFaxScanDemoView",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "无法从所选照片加载图像。"]
                )
            }

            await MainActor.run {
                self.selectedOCRImage = uiImage
            }

            // 2. 保存为临时文件，生成一个本地路径供 OCRTool 使用
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("ocr-\(UUID().uuidString).jpg")

            guard let jpegData = uiImage.jpegData(compressionQuality: 0.9) else {
                throw NSError(
                    domain: "ToolFaxScanDemoView",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "无法编码图片为 JPEG。"]
                )
            }

            try jpegData.write(to: tempURL)

            // 3. 调用 OCRTool（使用你刚刚改好的真实实现）
            let result = try await ocrTool.call(
                arguments: OCRTool.Arguments(imageId: tempURL.path)
            )

            await MainActor.run {
                self.ocrRawText = result.extractedText

                // 4. 自动把识别出来的原始文本塞进 userPrompt
                self.userPrompt = """
                我从一张照片中通过 OCR 识别出了下面的原始文本，请帮我整理关键信息并用中文总结（例如姓名、金额、日期、文档类型等）：

                \(result.extractedText)
                """
            }
        } catch {
            await MainActor.run {
                self.ocrErrorMessage = "OCR 失败：\(error.localizedDescription)"
            }
        }

        await MainActor.run {
            self.isRunningOCR = false
        }
    }
    
    private var isModelAvailable: Bool {
        if case .available = systemModel.availability {
            return true
        }
        return false
    }
    
    // MARK: - 核心：把 Tool 丢给 LanguageModelSession，让模型自动决定何时调用
    
    private func runWithTools() async {
        guard isModelAvailable else {
            errorMessage = "System model unavailable. Turn on Apple Intelligence."
            return
        }
        
        let trimmedPrompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            errorMessage = "请输入一个问题，例如：这份传真能不能用免费页？"
            return
        }
        
        isGenerating = true
        errorMessage = nil
        outputText = ""
        
        do {
            // 1. Instructions：告诉模型什么时候应该用哪个 Tool
            let instructions = Instructions {
                "You are a Fax & Scan assistant."
                "If the user asks about fax cost, free pages, or how many credits a fax will use, you SHOULD call the 'estimateFaxQuote' tool."
                "If the user asks about how to scan a document or which preset to use, you SHOULD call the 'suggestScanPreset' tool."
                "After using tools, explain the result in the same language as the user, and be concise."
            }
            let tools: [any Tool] = [
                faxTool,
                scanTool,
                lookupContactTool,
                recentFaxTool,
                documentSearchTool,
                ocrTool,
                pdfPageCountTool,
                pdfCompressTool,
                faxCoverTool,
                workflowSimulateTool
            ]

            let session = LanguageModelSession(tools: tools, instructions: instructions)
            
            // 2. 工具列表
            
            // 3. GenerationOptions：让模型自动决定是否调用工具
            var options = GenerationOptions()
            options.sampling = .greedy
            options.temperature = 0.5
            // 4. 调用 respond，框架会：
            //    - 把 tools 的 name + description + 参数 schema 注入到 prompt 里
            //    - 模型根据需要决定调用哪个 tool、多次调用、顺序等
            let response = try await session.respond(
                to: trimmedPrompt,
                options: options
            )
            
            outputText = response.content
            
            // 如果你想 debug 工具调用，可以在这里查看 session.transcript 里 .toolCalls / .toolOutput
            // 然后在自己的 “HistoryView” 里可视化出来。
            
        } catch let genError as LanguageModelSession.GenerationError {
            switch genError {
            case .exceededContextWindowSize(let size):
                errorMessage = "Exceeded context window (\(size) tokens). Try a shorter conversation."
            case .guardrailViolation:
                errorMessage = "Request was blocked by guardrails. Try a different wording."
            default:
                errorMessage = "Generation error: \(genError.localizedDescription)"
            }
        } catch {
            errorMessage = "Failed to generate: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
}

func requestContactAccess() async -> Bool {
    let store = CNContactStore()

    let status = CNContactStore.authorizationStatus(for: .contacts)
    if status == .authorized {
        return true
    }

    return await withCheckedContinuation { continuation in
        store.requestAccess(for: .contacts) { granted, error in
            continuation.resume(returning: granted)
        }
    }
}
