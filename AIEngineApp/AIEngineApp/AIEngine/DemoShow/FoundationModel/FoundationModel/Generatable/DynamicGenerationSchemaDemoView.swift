//
//  DynamicFaxPlan.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


//
//  DynamicGenerationSchemaDemoView.swift
//  AIEngineApp
//
//  Demo：展示 DynamicGenerationSchema + GenerationSchema 的用法
//  业务场景：Jet Fax 根据“可用线路 / 动作列表”在运行时动态约束模型输出
//

import SwiftUI
import Foundation
import FoundationModels

// 用来在 UI 中展示解析后的结果（不需要 Generable）
struct DynamicFaxPlan {
    let fromNumber: String
    let destinationCategory: String
    let action: String
    let addCoverPage: Bool
    let priority: Int
}

@MainActor
struct DynamicGenerationSchemaDemoView: View {
    
    // Apple Intelligence 模型
    private let systemModel = SystemLanguageModel.default
    @State private var session: LanguageModelSession?
    
    // 模拟“后端/远端配置”——真实项目里可以从服务器拉：
    @State private var availableFaxNumbers: [String] = [
        "+1-555-1001",
        "+1-555-IRS-TAX",
        "+1-555-CLAIMS"
    ]
    
    @State private var destinationCategories: [String] = [
        "IRS",
        "Insurance",
        "Bank",
        "HR Department",
        "Other"
    ]
    
    @State private var availableActions: [String] = [
        "send_now",
        "schedule_for_tonight",
        "save_draft_only"
    ]
    
    // 用户的自然语言描述
    @State private var userDescription: String = """
    这是一份 2024 年的 IRS 报税表，需要在本周内发给税务局。
    我希望今天先保存草稿，今晚系统自动发送，并加一页封面说明。
    """
    
    // 状态
    @State private var isRunning: Bool = false
    @State private var errorMessage: String?
    @State private var lastPlan: DynamicFaxPlan?
    @State private var rawGeneratedDebug: String?
    
    public var body: some View {
        Form {
            // 模型可用性
            Section("Model Availability") {
                Text(systemModel.availability.description)
                    .font(.footnote)
                    .foregroundColor(systemModel.availability == .available ? .green : .red)
            }
            
            // 展示“运行时选项”
            Section("Runtime options (模拟后端配置)") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📠 可用发件号码：")
                        .bold()
                    Text(availableFaxNumbers.joined(separator: " · "))
                        .font(.footnote)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("🎯 收件方类型：")
                        .bold()
                    Text(destinationCategories.joined(separator: " · "))
                        .font(.footnote)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚙️ 可执行动作：")
                        .bold()
                    Text(availableActions.joined(separator: " · "))
                        .font(.footnote)
                }
                Text("注意：这些选项不是写死在代码里的，可以在运行时由服务器下发；我们会用 DynamicGenerationSchema 把它们变成模型必须遵守的 schema。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 用户描述
            Section("User description（文档 + 意图）") {
                TextEditor(text: $userDescription)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2))
                    )
                
                Text("你可以直接粘贴真实的 OCR 文本 + 自己的需求说明，比如：想今晚 23 点发给 IRS，需要加封面之类。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 触发生成
            Section("Generate with DynamicGenerationSchema") {
                Button {
                    Task { await runDynamicSchemaGeneration() }
                } label: {
                    HStack {
                        if isRunning { ProgressView() }
                        Text("生成 Fax 发送计划（使用动态 Schema）")
                    }
                }
                .disabled(isRunning || userDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            
            // 解析后的结果（强类型）
            if let plan = lastPlan {
                Section("Decoded result (强类型 DynamicFaxPlan)") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📠 发件号码：\(plan.fromNumber)")
                        Text("🎯 收件方类型：\(plan.destinationCategory)")
                        Text("⚙️ 动作：\(humanReadableAction(plan.action))")
                        Text("📄 是否加封面：\(plan.addCoverPage ? "是" : "否")")
                        Text("🔥 优先级：\(plan.priority) / 3")
                    }
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
        .navigationTitle("DynamicGenerationSchema Demo")
    }
    
    // MARK: - 核心逻辑：运行时构建 DynamicGenerationSchema ------------------
    
    private func ensureSessionIfNeeded() {
        guard session == nil else { return }
        
        let instructions = Instructions {
            """
            You are an on-device assistant inside the Fax app.
            You must NOT invent arbitrary values. You must STRICTLY choose
            values that satisfy the dynamic generation schema you receive.

            The user will describe a document and their wishes in natural language.
            Based on that description and the available options, you should choose:

            - fromNumber: which fax line to use
            - destinationCategory: which high-level receiver category
            - action: what to do with this document (send now, schedule, or save draft)
            - addCoverPage: whether to include a cover page
            - priority: 1 (low), 2 (normal), or 3 (high)

            Always think from the user's perspective and pick the most reasonable
            combination of options.
            """
        }
        
        session = LanguageModelSession(
            model: systemModel,
            instructions: instructions
        )
    }
    
    private func runDynamicSchemaGeneration() async {
        guard systemModel.availability == .available else {
            errorMessage = "SystemLanguageModel 不可用，请在设置中开启 Apple Intelligence。"
            return
        }
        
        ensureSessionIfNeeded()
        guard let session else { return }
        
        isRunning = true
        errorMessage = nil
        rawGeneratedDebug = nil
        
        do {
            // 1. 构建动态枚举 schema：fromNumber / destinationCategory / action
            let fromNumberEnum = DynamicGenerationSchema(
                name: "FromNumber",
                description: "One of the fax numbers the user owns.",
                anyOf: availableFaxNumbers
            )
            
            let destinationEnum = DynamicGenerationSchema(
                name: "DestinationCategory",
                description: "High level category of the receiver.",
                anyOf: destinationCategories
            )
            
            let actionEnum = DynamicGenerationSchema(
                name: "Action",
                description: "Action Fax should perform.",
                anyOf: availableActions
            )
            
            // 2. 使用基本类型 + GenerationGuide 构建 priority / addCoverPage
            let addCoverSchema = DynamicGenerationSchema(type: Bool.self)
            
            let prioritySchema = DynamicGenerationSchema(
                type: Int.self,
                guides: [GenerationGuide.range(1...3)]
            )
            
            // 3. 组合成一个对象 schema 作为 root
            let root = DynamicGenerationSchema(
                name: "FaxSendPlan",
                description: "A plan describing how to send or store the current document.",
                properties: [
                    .init(
                        name: "fromNumber",
                        description: "Which fax line to use.",
                        schema: DynamicGenerationSchema(referenceTo: "FromNumber")
                    ),
                    .init(
                        name: "destinationCategory",
                        description: "Receiver category.",
                        schema: DynamicGenerationSchema(referenceTo: "DestinationCategory")
                    ),
                    .init(
                        name: "action",
                        description: "What to do with this document.",
                        schema: DynamicGenerationSchema(referenceTo: "Action")
                    ),
                    .init(
                        name: "addCoverPage",
                        description: "Whether to include a cover page.",
                        schema: addCoverSchema
                    ),
                    .init(
                        name: "priority",
                        description: "Priority from 1 (low) to 3 (high).",
                        schema: prioritySchema
                    )
                ]
            )
            
            // 4. 把 dynamic schema 转成真正的 GenerationSchema
            let generationSchema = try GenerationSchema(
                root: root,
                dependencies: [fromNumberEnum, destinationEnum, actionEnum]
            )
            
            // 5. 调用模型，指定 schema 而不是 Generable 类型
            let options = GenerationOptions(
                sampling: .greedy,    // 结构化输出，优先稳定
                temperature: 0.0,
                maximumResponseTokens: 128
            )
            
            let generated: GeneratedContent = try await session.respond(
                to: """
                    User description of the document and wishes:

                    \(userDescription)
                    """,
                schema: generationSchema,
                options: options
            ).content
            
            // 6. 通过 value(_:forProperty:) 解析为强类型 Swift 值
            let fromNumber = try generated.value(String.self, forProperty: "fromNumber")
            let destinationCategory = try generated.value(String.self, forProperty: "destinationCategory")
            let action = try generated.value(String.self, forProperty: "action")
            let addCoverPage = try generated.value(Bool.self, forProperty: "addCoverPage")
            let priority = try generated.value(Int.self, forProperty: "priority")
            
            let plan = DynamicFaxPlan(
                fromNumber: fromNumber,
                destinationCategory: destinationCategory,
                action: action,
                addCoverPage: addCoverPage,
                priority: priority
            )
            
            self.lastPlan = plan
            self.rawGeneratedDebug = generated.debugDescription.description
        } catch {
            self.errorMessage = "生成失败：\(error.localizedDescription)"
        }
        
        isRunning = false
    }
    
    // 把机器可读的 action 转成用户友好文案
    private func humanReadableAction(_ action: String) -> String {
        switch action {
        case "send_now":             return "立即发送传真"
        case "schedule_for_tonight": return "今晚定时发送"
        case "save_draft_only":      return "仅保存草稿"
        default:                     return action
        }
    }
}

// 小工具：让 Availability 打印得更友好一点
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
