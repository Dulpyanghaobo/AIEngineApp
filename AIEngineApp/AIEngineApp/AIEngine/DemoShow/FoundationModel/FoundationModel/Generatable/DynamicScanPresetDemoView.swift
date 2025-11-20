//
//  DemoScanPreset.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


//
//  DynamicScanPresetDemoView.swift
//  AIEngineApp
//
//  场景 5：扫描预设（多字段 object）
//  - 后端根据设备 / 会员等级提供不同 scanning preset（id + dpi + color）。
//  - 使用 DynamicGenerationSchema 构造 ScanPreset（多字段 object） + ColorMode enum。
//  - 让模型根据用户扫描需求，推荐最合适的扫描预设，并给出中文解释。
//

import SwiftUI
import Foundation
import FoundationModels

// MARK: - 模拟后端返回的扫描预设 ------------------------------------------------------

struct DemoScanPreset: Identifiable, Equatable {
    let id: String
    let dpi: Int
    let color: String      // "color" / "grayscale" / "bw"
    let description: String
    
    var displayName: String {
        "\(id) (\(dpi) dpi, \(color))"
    }
    
    var swiftID: String { id } // 方便 tag 使用
}

@MainActor
struct DynamicScanPresetDemoView: View {
    
    // MARK: - Apple Intelligence
    
    private let systemModel = SystemLanguageModel.default
    @State private var session: LanguageModelSession?
    
    // MARK: - 模拟后端 / 配置提供的 presets（可以根据设备/会员动态变化）
    
    private let dynamicPresets: [DemoScanPreset] = [
        DemoScanPreset(
            id: "auto",
            dpi: 300,
            color: "color",
            description: "自动模式，适合大多数文档，颜色 & 对比度自动优化。"
        ),
        DemoScanPreset(
            id: "doc_fast",
            dpi: 200,
            color: "grayscale",
            description: "快速文档模式，灰度扫描，文件较小，适合合同/票据备份。"
        ),
        DemoScanPreset(
            id: "high_quality",
            dpi: 600,
            color: "color",
            description: "高质量模式，适合带照片、彩色报告，文件会比较大。"
        )
    ]
    
    // MARK: - 用户输入 & 状态
    
    /// 用户扫描需求（描述场景），给模型看
    @State private var userScanGoal: String = """
    我在光线不太好的房间里扫描一份 20 页的合同，主要是保存到 iCloud 作为长期备份。
    希望文字清晰，可以看很细的条款，但文件也不要太大，方便以后分享给律师或会计。
    """
    
    @State private var isRunning: Bool = false
    @State private var errorMessage: String?
    
    struct ScanPresetSuggestionResult {
        let id: String
        let dpi: Int
        let color: String
        let reason: String
    }
    
    @State private var result: ScanPresetSuggestionResult?
    @State private var rawGeneratedDebug: String?
    
    var body: some View {
        Form {
            // 模型可用性
            Section("Model Availability") {
                Text(systemModel.availability.description)
                    .font(.footnote)
                    .foregroundColor(systemModel.availability == .available ? .green : .red)
            }
            
            // 展示当前可用扫描预设（模拟后端数据）
            Section("当前可用扫描预设（动态提供）") {
                ForEach(dynamicPresets) { preset in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.id)
                            .font(.headline)
                        Text("DPI：\(preset.dpi)")
                            .font(.subheadline)
                        Text("颜色模式：\(preset.color)")
                            .font(.subheadline)
                        Text(preset.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Text("""
                这些 preset 相当于你从后端 / 本地配置拿到的动态列表：
                - 不同设备可能没有 high_quality
                - 免费用户可能只开放 auto / doc_fast
                DynamicGenerationSchema 不关心具体有几个 preset，只关心结果的结构。
                """)
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            // 用户扫描需求
            Section("扫描需求描述（输入给模型）") {
                TextEditor(text: $userScanGoal)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2))
                    )
                
                Text("""
                建议用户写清楚：
                - 文档类型：合同 / 报税表 / 照片 / 收据
                - 使用场景：仅备份 / 邮件发送 / 打印
                - 对大小和清晰度的偏好。
                """)
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            // 触发生成
            Section("让模型推荐扫描预设（DynamicGenerationSchema）") {
                Button {
                    Task { await runScanPresetSuggestion() }
                } label: {
                    HStack {
                        if isRunning { ProgressView() }
                        Text("选择最合适的扫描预设")
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
                Section("推荐结果") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("推荐预设 ID")
                            .font(.headline)
                        Text(result.id)
                            .font(.title3)
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("DPI")
                            .font(.headline)
                        Text("\(result.dpi)")
                            .font(.title3)
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("颜色模式")
                            .font(.headline)
                        Text(result.color)
                            .font(.title3)
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("模型解释（中文）")
                            .font(.headline)
                        Text(result.reason)
                            .font(.subheadline)
                    }
                }
            }
            
            // 调试：GeneratedContent 的结构
            if let raw = rawGeneratedDebug {
                Section("Raw GeneratedContent（调试用）") {
                    ScrollView {
                        Text(raw)
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 80, maxHeight: 200)
                }
            }
        }
        .navigationTitle("动态扫描预设推荐")
    }
    
    // MARK: - Session & 调用逻辑 -----------------------------------------------------
    
    private func ensureSessionIfNeeded() {
        guard session == nil else { return }
        
        let instructions = Instructions {
            """
            You are an on-device assistant inside the Jet Scan / Jet PDF app.

            The app will give you:
            1. A list of available scan presets (id, dpi, color, description).
            2. A natural language description of the user's scanning goal (in Chinese).

            Your task:
            - Choose ONE scan preset that best fits the user's scenario.
            - You may slightly adjust dpi within a reasonable range if necessary,
              but explain why.
            - Color must be one of: "color", "grayscale", "bw".
            - Explain your reasoning in Chinese.

            You MUST:
            - Prefer one of the existing preset IDs when possible.
            - Respect the numeric constraint of dpi between 72 and 1200.
            """
        }
        
        session = LanguageModelSession(
            model: systemModel,
            instructions: instructions
        )
    }
    
    private func runScanPresetSuggestion() async {
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
            // 1. ColorMode 枚举 schema（anyOf [String]）
            let colorEnum = DynamicGenerationSchema(
                name: "ColorMode",
                description: "Scanning color mode.",
                anyOf: ["color", "grayscale", "bw"]
            )
            
            // 2. DPI 数值范围 schema（Int + range）
            let dpiSchema = DynamicGenerationSchema(
                type: Int.self,
                guides: [GenerationGuide.range(72...1200)]
            )
            
            // 3. ScanPreset 多字段 object schema
            let presetSchema = DynamicGenerationSchema(
                name: "ScanPreset",
                description: "A scan preset with id, dpi, and color mode.",
                properties: [
                    .init(
                        name: "id",
                        description: "Preset identifier.",
                        schema: DynamicGenerationSchema(type: String.self)
                    ),
                    .init(
                        name: "dpi",
                        description: "Dots per inch for scanning.",
                        schema: dpiSchema
                    ),
                    .init(
                        name: "color",
                        description: "Color mode for scanning.",
                        schema: DynamicGenerationSchema(referenceTo: "ColorMode")
                    )
                ]
            )
            
            // 4. 定义一个 result object：包含推荐的 ScanPreset + reason
            let decisionSchema = DynamicGenerationSchema(
                name: "ScanPresetDecision",
                description: "The chosen scan preset for the user's scenario.",
                properties: [
                    .init(
                        name: "chosenPreset",
                        description: "The chosen scan preset.",
                        schema: DynamicGenerationSchema(referenceTo: "ScanPreset")
                    ),
                    .init(
                        name: "reason",
                        description: "Chinese explanation of why this preset is chosen.",
                        schema: DynamicGenerationSchema(type: String.self)
                    )
                ]
            )
            
            // 5. 构建 GenerationSchema（root: decision, deps: [colorEnum, presetSchema]）
            let generationSchema = try GenerationSchema(
                root: decisionSchema,
                dependencies: [colorEnum, presetSchema]
            )
            
            // 6. 把 dynamicPresets 描述成文本给模型参考
            let presetsText = dynamicPresets
                .enumerated()
                .map { index, p in
                    """
                    [\(index + 1)] id: \(p.id)
                        - dpi: \(p.dpi)
                        - color: \(p.color)
                        - 描述：\(p.description)
                    """
                }
                .joined(separator: "\n\n")
            
            let prompt = """
            以下是当前设备 / 会员等级下可用的扫描预设：

            \(presetsText)

            用户的扫描需求描述如下：
            \(userScanGoal)

            请在上面的预设基础上，选择一个最合适的扫描 preset：
            - 如果现有 preset 已经适合，可以直接复用它的 id / dpi / color。
            - 如有必要，你可以在 72~1200 范围内微调 dpi（例如从 300 调整到 350），但要在理由中说明。
            - color 必须是 "color"、"grayscale" 或 "bw" 之一。
            - 最终请输出一个 ScanPresetDecision 对象：
              - chosenPreset: { id, dpi, color }
              - reason: 用中文解释你选择这个 preset 的原因（和其他 preset 的对比）。
            """
            
            let options = GenerationOptions(
                sampling: .greedy,    // 结构化输出优先稳定
                temperature: 0.0,
                maximumResponseTokens: 256
            )
            
            // 7. 调用模型，使用动态 schema 约束输出结构
            let generatedContent = try await session.respond(
                to: prompt,
                schema: generationSchema,
                options: options
            ).content
            
            // 8. 从 GeneratedContent 中解析结果
            let chosenPresetContent = try generatedContent.value(
                GeneratedContent.self,
                forProperty: "chosenPreset"
            )
            
            let id = try chosenPresetContent.value(String.self, forProperty: "id")
            let dpi = try chosenPresetContent.value(Int.self, forProperty: "dpi")
            let color = try chosenPresetContent.value(String.self, forProperty: "color")
            let reason = try generatedContent.value(String.self, forProperty: "reason")
            
            self.result = ScanPresetSuggestionResult(
                id: id,
                dpi: dpi,
                color: color,
                reason: reason
            )
            
            self.rawGeneratedDebug = generatedContent.debugDescription.description
            
        } catch {
            self.errorMessage = "生成失败：\(error.localizedDescription)"
        }
        
        isRunning = false
    }
}

// MARK: - Availability 描述（和其他 Demo 统一）

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
