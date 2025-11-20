//
//  OCRLanguageInfo.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//

import SwiftUI
import Foundation
import FoundationModels

// 模拟一条 "语言支持" 记录，方便在 UI 里展示
struct OCRLanguageInfo: Identifiable, Equatable {
    let id: String          // 语言 code，例如 "en-US"
    let displayName: String // UI 展示用文案
    let note: String        // 说明，用来让用户理解
}

@MainActor
struct DynamicOCRLanguageSelectionDemoView: View {
    
    // MARK: - Apple Intelligence 模型 ------------------------------------------------
    
    private let systemModel = SystemLanguageModel.default
    @State private var session: LanguageModelSession?
    
    // MARK: - 模拟“当前支持的 OCR 语言列表”
    //
    // 这里你以后可以换成：
    // - 从 Vision / OCRKit 动态获取支持语言
    // - 从 Remote Config / 后端接口返回
    
    private let supportedLanguages: [OCRLanguageInfo] = [
        .init(
            id: "en-US",
            displayName: "English (US)",
            note: "美国英文文档、合同、发票等"
        ),
        .init(
            id: "zh-CN",
            displayName: "简体中文",
            note: "大陆地区中文文件，包含发票、报税资料等"
        ),
        .init(
            id: "ja-JP",
            displayName: "日本語",
            note: "日本签证材料、银行单据等"
        ),
        .init(
            id: "ko-KR",
            displayName: "한국어",
            note: "韩国账单、留学材料等"
        ),
        .init(
            id: "es-ES",
            displayName: "Español (Spain)",
            note: "西班牙/部分拉美文档"
        )
    ]
    
    // 把语言 id 提取成 [String]，用来做 DynamicGenerationSchema(anyOf:)
    private var ocrLanguageCodes: [String] {
        supportedLanguages.map { $0.id }
    }
    
    // MARK: - 用户输入 & 状态 --------------------------------------------------------
    
    @State private var userDocDescription: String = """
    我有一份报税相关的扫描 PDF，第一页是英文说明，后面有几页是中文表格，
    主要内容是给美国 IRS 和国内税务局备份使用，希望识别结果中英文都尽量准确。
    """
    
    @State private var isRunning: Bool = false
    @State private var errorMessage: String?
    
    struct OCRLanguageSuggestionResult {
        let primaryLanguage: OCRLanguageInfo?
        let secondaryLanguage: OCRLanguageInfo?
        let explanation: String
    }
    
    @State private var result: OCRLanguageSuggestionResult?
    @State private var rawGeneratedDebug: String?
    
    var body: some View {
        Form {
            // 模型可用性
            Section("Model Availability") {
                Text(systemModel.availability.description)
                    .font(.footnote)
                    .foregroundColor(systemModel.availability == .available ? .green : .red)
            }
            
            // 当前支持的 OCR 语言列表
            Section("当前设备支持的 OCR 语言（模拟）") {
                ForEach(supportedLanguages) { lang in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.displayName)
                            .bold()
                        Text(lang.id)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(lang.note)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Text("这里相当于你从系统 / 后端获取的 OCR 支持语言列表，数量和内容都可以在运行时变化。DynamicGenerationSchema 会在运行时根据这些列表生成枚举。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 用户描述文档类型和使用场景
            Section("文档描述 & 使用场景") {
                TextEditor(text: $userDocDescription)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2))
                    )
                
                Text("建议用户写：文档主要是什么语言、要给谁用（IRS、移民局、银行）、是打印扫描还是手机拍照等。模型会根据这些信息帮你选 primary / secondary OCR 语言。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 触发生成
            Section("生成 OCR 语言选择（DynamicGenerationSchema）") {
                Button {
                    Task { await runLanguageSelection() }
                } label: {
                    HStack {
                        if isRunning { ProgressView() }
                        Text("让模型为这份文档选择 OCR 语言")
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
                Section("模型建议的 OCR 语言") {
                    VStack(alignment: .leading, spacing: 6) {
                        if let primary = result.primaryLanguage {
                            Text("Primary （主识别语言）")
                                .font(.headline)
                            Text("\(primary.displayName)  (\(primary.id))")
                            Text(primary.note)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("没有成功解析 primaryLanguage")
                                .foregroundColor(.orange)
                        }
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("Secondary （辅助识别语言，可选）")
                            .font(.headline)
                        if let secondary = result.secondaryLanguage {
                            Text("\(secondary.displayName)  (\(secondary.id))")
                            Text(secondary.note)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("模型没有设置 secondaryLanguage（可能认为单语识别更适合）。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
                
                Section("模型解释（为什么这样选）") {
                    Text(result.explanation)
                        .font(.subheadline)
                }
            }
            
            // 调试：GeneratedContent 原始结构
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
        .navigationTitle("动态 OCR 语言选择")
    }
    
    // MARK: - Session / 调用逻辑 ----------------------------------------------------
    
    private func ensureSessionIfNeeded() {
        guard session == nil else { return }
        
        let instructions = Instructions {
            """
            You are an on-device assistant inside the Jet Scan app.

            The app will give you:
            1. A list of OCR languages that the device currently supports.
            2. A natural language description of the document and usage scenario (in Chinese).

            Your task:
            - Choose ONE `primaryLanguage` from the given OCRLanguage list.
            - Optionally choose ONE `secondaryLanguage` (or omit it).
            - Explain your choice in Chinese as `explanation`.

            You MUST only use language codes from the provided OCRLanguage list.
            Do NOT invent new language codes.
            """
        }
        
        session = LanguageModelSession(
            model: systemModel,
            instructions: instructions
        )
    }
    
    private func runLanguageSelection() async {
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
            // 1. OCRLanguage 枚举（anyOf [String]）
            let languageEnum = DynamicGenerationSchema(
                name: "OCRLanguage",
                description: "Language codes supported by OCR engine.",
                anyOf: ocrLanguageCodes
            )
            
            // 2. OCRRequest 对象 schema（primaryLanguage + optional secondaryLanguage + explanation）
            let ocrRequestSchema = DynamicGenerationSchema(
                name: "OCRRequest",
                description: "Language selection for OCR task.",
                properties: [
                    .init(
                        name: "primaryLanguage",
                        description: "Primary OCR language to use.",
                        schema: DynamicGenerationSchema(referenceTo: "OCRLanguage")
                    ),
                    .init(
                        name: "secondaryLanguage",
                        description: "Optional secondary OCR language.",
                        schema: DynamicGenerationSchema(referenceTo: "OCRLanguage"),
                        isOptional: true
                    ),
                    .init(
                        name: "explanation",
                        description: "Explanation in Chinese for why these languages are chosen.",
                        schema: DynamicGenerationSchema(type: String.self)
                    )
                ]
            )
            
            // 3. 构建 GenerationSchema（root: OCRRequest，依赖：OCRLanguage）
            let generationSchema = try GenerationSchema(
                root: ocrRequestSchema,
                dependencies: [languageEnum]
            )
            
            // 4. 构建 prompt
            let languagesDescription = supportedLanguages
                .map { "- \($0.id): \($0.displayName) — \($0.note)" }
                .joined(separator: "\n")
            
            let prompt = """
            下面是当前设备支持的 OCR 语言列表：
            \(languagesDescription)

            文档与使用场景描述：
            \(userDocDescription)

            请根据文档内容和使用场景，从上面提供的语言代码里：
            - 选择一个最合适的 primaryLanguage
            - 可以选择一个 secondaryLanguage（如果你认为有必要）
            - 用中文解释你为什么这样选择
            """
            
            let options = GenerationOptions(
                sampling: .greedy,    // 结构化任务，优先稳定输出
                temperature: 0.0,
                maximumResponseTokens: 256
            )
            
            // 5. 调用模型（schema + DynamicGenerationSchema）
            let generatedContent = try await session.respond(
                to: prompt,
                schema: generationSchema,
                options: options
            ).content
            
            // 6. 解析 GeneratedContent
            let primaryCode = try generatedContent.value(String.self, forProperty: "primaryLanguage")
            let secondaryCode: String? = try? generatedContent.value(
                String.self,
                forProperty: "secondaryLanguage"
            )
            let explanation = try generatedContent.value(String.self, forProperty: "explanation")
            
            let primaryInfo = supportedLanguages.first(where: { $0.id == primaryCode })
            let secondaryInfo = secondaryCode.flatMap { code in
                supportedLanguages.first(where: { $0.id == code })
            }
            
            self.result = OCRLanguageSuggestionResult(
                primaryLanguage: primaryInfo,
                secondaryLanguage: secondaryInfo,
                explanation: explanation
            )
            
            self.rawGeneratedDebug = generatedContent.debugDescription.description
            
        } catch {
            self.errorMessage = "生成失败：\(error.localizedDescription)"
        }
        
        isRunning = false
    }
}

// MARK: - Availability 描述小工具（和前一个 Demo 保持一致）

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
