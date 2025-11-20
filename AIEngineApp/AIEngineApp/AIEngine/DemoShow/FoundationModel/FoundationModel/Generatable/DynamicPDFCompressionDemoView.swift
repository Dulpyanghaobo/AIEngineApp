//
//  SamplePDFInfo.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


//
//  DynamicPDFCompressionDemoView.swift
//  AIEngineApp
//
//  场景 3：动态 PDF 压缩设置（DynamicGenerationSchema + 数值范围）
//  - 模拟后端提供的压缩器列表 ["fast", "balanced", "high_quality"]
//  - 使用 DynamicGenerationSchema 构造 CompressorType + PDFCompressionConfig
//  - 让模型根据 PDF 元信息 + 用户用途，推荐压缩设置
//

import SwiftUI
import Foundation
import FoundationModels

// MARK: - 模拟 PDF 元信息模型（纯 Swift，用于 UI 展示） ----------------------------

struct SamplePDFInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let pages: Int
    let currentSizeMB: Double
    let hasColor: Bool
    let hasPhotos: Bool
    let isScanned: Bool
    let note: String
}

// UI 用结果
struct CompressionSuggestionResult {
    let compressor: String
    let targetMB: Double
    let preserveColor: Bool?
    let explanation: String
}

@MainActor
struct DynamicPDFCompressionDemoView: View {
    
    // MARK: - Apple Intelligence 模型
    
    private let systemModel = SystemLanguageModel.default
    @State private var session: LanguageModelSession?
    
    // MARK: - 模拟后端提供的压缩器列表
    
    private let compressors = ["fast", "balanced", "high_quality"]
    
    private var compressorDescriptions: [String: String] {
        [
            "fast": "优先速度，压缩较多，适合预览或临时分享。",
            "balanced": "画质与体积折中，适合大多数邮件 / 云盘上传场景。",
            "high_quality": "尽量保留画质，压缩较少，适合打印 / 存档。"
        ]
    }
    
    // MARK: - 模拟几种 PDF 文件场景
    
    private let samplePDFs: [SamplePDFInfo] = [
        .init(
            id: "tax_return",
            title: "2024 IRS Tax Return (扫描件)",
            pages: 32,
            currentSizeMB: 38.5,
            hasColor: false,
            hasPhotos: true,
            isScanned: true,
            note: "大部分是黑白文字 + 少量票据照片，需要通过 email 提交给会计和 IRS。"
        ),
        .init(
            id: "insurance_claim",
            title: "保险理赔材料（中英混合）",
            pages: 18,
            currentSizeMB: 26.2,
            hasColor: true,
            hasPhotos: true,
            isScanned: true,
            note: "包含彩色检查单、照片，需要上传到保险公司网站，有 20 MB 上传限制。"
        ),
        .init(
            id: "long_contract",
            title: "租房合同 + 附件（电子签名版）",
            pages: 56,
            currentSizeMB: 12.7,
            hasColor: true,
            hasPhotos: false,
            isScanned: false,
            note: "主要是矢量文字，文件原本就不大，希望保持字体清晰方便长久存档。"
        )
    ]
    
    @State private var selectedPDFID: String = "tax_return"
    
    private var selectedPDF: SamplePDFInfo {
        samplePDFs.first(where: { $0.id == selectedPDFID }) ?? samplePDFs[0]
    }
    
    // MARK: - 用户输入 & 状态
    
    @State private var userGoalDescription: String = """
    我打算把这个 PDF 通过邮件发给对方，对方的邮箱系统对附件大小比较敏感，
    最好控制在 10 MB 左右，但又希望主要内容不要糊掉，能清楚打印出来。
    """
    
    @State private var isRunning: Bool = false
    @State private var errorMessage: String?
    
    @State private var result: CompressionSuggestionResult?
    @State private var rawGeneratedDebug: String?
    
    var body: some View {
        Form {
            // 模型可用性
            Section("Model Availability") {
                Text(systemModel.availability.description)
                    .font(.footnote)
                    .foregroundColor(systemModel.availability == .available ? .green : .red)
            }
            
            // 可选 PDF 列表
            Section("选择一个 PDF 场景（模拟）") {
                Picker("文档", selection: $selectedPDFID) {
                    ForEach(samplePDFs) { pdf in
                        Text(pdf.title).tag(pdf.id)
                    }
                }
                
                let pdf = selectedPDF
                VStack(alignment: .leading, spacing: 6) {
                    Text(pdf.title)
                        .font(.headline)
                    Text("页数：\(pdf.pages) 页")
                    Text(String(format: "当前大小：%.2f MB", pdf.currentSizeMB))
                    Text("颜色：\(pdf.hasColor ? "包含彩色" : "主要是黑白")")
                    Text("是否有照片：\(pdf.hasPhotos ? "有" : "无")")
                    Text("来源：\(pdf.isScanned ? "扫描件" : "电子生成 PDF")")
                    Text("备注：\(pdf.note)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                .padding(.vertical, 4)
                
                Text("这些信息相当于你在本地就可以拿到的 PDF 元数据：页数、当前大小、是否彩色 / 有照片等，用来指导模型选择压缩策略。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 后端压缩器列表展示
            Section("当前可用压缩器（后端 / 配置提供）") {
                ForEach(compressors, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(key)
                            .font(.subheadline)
                            .bold()
                        Text(compressorDescriptions[key] ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                
                Text("这里模拟后端给出的压缩策略：不同机型、不同订阅等级时，你可以动态增删策略（比如只开放 fast + balanced 给免费用户）。DynamicGenerationSchema 会自动跟着变化。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 用户目标
            Section("用户压缩目标描述") {
                TextEditor(text: $userGoalDescription)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2))
                    )
                
                Text("建议用户写：要不要发邮件 / 上传网站，有没有大小上限，打印需求、是否需要保留彩色等。模型会综合 PDF 信息和这段描述。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 触发生成
            Section("生成压缩配置（DynamicGenerationSchema）") {
                Button {
                    Task { await runCompressionSuggestion() }
                } label: {
                    HStack {
                        if isRunning { ProgressView() }
                        Text("让模型推荐压缩设置")
                    }
                }
                .disabled(isRunning)
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            
            // 结果展示
            if let result {
                Section("推荐的压缩配置") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Compressor")
                            .font(.headline)
                        Text(result.compressor)
                        Text(compressorDescriptions[result.compressor] ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("目标大小（targetMB）")
                            .font(.headline)
                        Text(String(format: "%.2f MB", result.targetMB))
                            .font(.title3)
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("是否保留彩色（preserveColor）")
                            .font(.headline)
                        if let keepColor = result.preserveColor {
                            Text(keepColor ? "是（保留彩色）" : "否（允许转灰度）")
                        } else {
                            Text("未指定（可以由你在本地按策略决定，比如对彩色照片默认保留）")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
                
                Section("模型解释（为什么这样压缩）") {
                    Text(result.explanation)
                        .font(.subheadline)
                }
            }
            
            // 调试：原始 GeneratedContent
            if let raw = rawGeneratedDebug {
                Section("Raw GeneratedContent (调试用)") {
                    ScrollView {
                        Text(raw)
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 80, maxHeight: 180)
                }
            }
        }
        .navigationTitle("动态 PDF 压缩配置")
    }
    
    // MARK: - Session / 调用逻辑 ----------------------------------------------------
    
    private func ensureSessionIfNeeded() {
        guard session == nil else { return }
        
        let instructions = Instructions {
            """
            You are an on-device assistant inside the Jet PDF / Jet Scan app.

            The app will give you:
            1. Metadata about a PDF file (pages, current size, hasColor, hasPhotos, etc.).
            2. A natural language description of how the user wants to use the file (in Chinese).
            3. A list of available compressor strategies.

            Your task:
            - Choose one compressor from the given list.
            - Choose a targetMB (between 0.1 and 50.0) that balances size and quality.
            - Optionally decide whether to preserveColor (true/false).
            - Explain your reasoning in Chinese.

            You MUST:
            - Only output compressor values from the provided list (fast / balanced / high_quality).
            - Respect the numeric range constraint on targetMB.
            """
        }
        
        session = LanguageModelSession(
            model: systemModel,
            instructions: instructions
        )
    }
    
    private func runCompressionSuggestion() async {
        guard systemModel.availability == .available else {
            errorMessage = "SystemLanguageModel 不可用，请在设置中开启 Apple Intelligence。"
            return
        }
        
        ensureSessionIfNeeded()
        guard let session else { return }
        
        isRunning = true
        errorMessage = nil
        result = nil
        rawGeneratedDebug = nil
        
        do {
            // 1. CompressorType 枚举 schema（anyOf [String]）
            let compressorEnum = DynamicGenerationSchema(
                name: "CompressorType",
                description: "Available PDF compressor strategies.",
                anyOf: compressors
            )
            
            // 2. targetMB 数值 schema（Double + 范围）
            let targetSizeSchema = DynamicGenerationSchema(
                type: Double.self,
                guides: [GenerationGuide<Double>.range(0.1...50.0)]
            )
            
            // 3. PDFCompressionConfig 对象 schema（包含 optional preserveColor + explanation）
            let compressionSchema = DynamicGenerationSchema(
                name: "PDFCompressionConfig",
                description: "Recommended compression settings for this PDF.",
                properties: [
                    .init(
                        name: "compressor",
                        description: "Which compressor to use.",
                        schema: DynamicGenerationSchema(referenceTo: "CompressorType")
                    ),
                    .init(
                        name: "targetMB",
                        description: "Desired PDF size in MB.",
                        schema: targetSizeSchema
                    ),
                    .init(
                        name: "preserveColor",
                        description: "Whether to keep color when compressing.",
                        schema: DynamicGenerationSchema(type: Bool.self),
                        isOptional: true
                    ),
                    .init(
                        name: "explanation",
                        description: "Short explanation in Chinese.",
                        schema: DynamicGenerationSchema(type: String.self)
                    )
                ]
            )
            
            // 4. 构建 GenerationSchema（root: PDFCompressionConfig，依赖: CompressorType）
            let generationSchema = try GenerationSchema(
                root: compressionSchema,
                dependencies: [compressorEnum]
            )
            
            // 5. 构建 prompt（把选中的 PDF 信息 + 用户目标描述丢给模型）
            let pdf = selectedPDF
            let pdfMeta = """
            选中的 PDF 信息：
            - 标题：\(pdf.title)
            - 页数：\(pdf.pages) 页
            - 当前大小：\(String(format: "%.2f", pdf.currentSizeMB)) MB
            - 是否包含彩色：\(pdf.hasColor ? "是" : "否")
            - 是否包含照片：\(pdf.hasPhotos ? "是" : "否")
            - 是否为扫描件：\(pdf.isScanned ? "是" : "否")
            - 备注：\(pdf.note)
            """
            
            let compressorsDescription = compressors
                .map { "- \($0): \(compressorDescriptions[$0] ?? "")" }
                .joined(separator: "\n")
            
            let prompt = """
            \(pdfMeta)

            可用压缩器列表：
            \(compressorsDescription)

            用户需求描述：
            \(userGoalDescription)

            请根据以上信息，推荐一套压缩设置：
            - 从压缩器列表中选一个 compressor
            - 在 0.1 ~ 50 MB 的范围内选择 targetMB
            - 可以视情况设置 preserveColor（true/false），如果不重要可以省略
            - 并用中文简要解释原因
            """
            
            let options = GenerationOptions(
                sampling: .greedy,    // 这里优先稳定结构化输出
                temperature: 0.0,
                maximumResponseTokens: 256
            )
            
            // 6. 调用模型（结构化输出）
            let generatedContent = try await session.respond(
                to: prompt,
                schema: generationSchema,
                options: options
            ).content
            
            // 7. 从 GeneratedContent 解析结果
            let compressor = try generatedContent.value(String.self, forProperty: "compressor")
            let targetMB = try generatedContent.value(Double.self, forProperty: "targetMB")
            let preserveColor: Bool? = try? generatedContent.value(Bool.self, forProperty: "preserveColor")
            let explanation = try generatedContent.value(String.self, forProperty: "explanation")
            
            self.result = CompressionSuggestionResult(
                compressor: compressor,
                targetMB: targetMB,
                preserveColor: preserveColor,
                explanation: explanation
            )
            
            self.rawGeneratedDebug = generatedContent.debugDescription.description
            
        } catch {
            self.errorMessage = "生成失败：\(error.localizedDescription)"
        }
        
        isRunning = false
    }
}

// MARK: - Availability 描述（跟前面两个 Demo 共用风格）

@available(iOS 18.0, macOS 15.0, *)
private extension SystemLanguageModel.Availability {
    var description: String {
        switch self {
        case .available:
            return "✅ available"
        case .unavailable(let reason):
            return "❌ \(String(describing: reason))"
        }
    }
}
