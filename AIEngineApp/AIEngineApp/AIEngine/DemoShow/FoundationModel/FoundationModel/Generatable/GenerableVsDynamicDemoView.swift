//
//  GenerableVsDynamicDemoView.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


import SwiftUI
import Foundation
import FoundationModels

@MainActor
struct GenerableVsDynamicDemoView: View {
    
    private let systemModel = SystemLanguageModel.default
    @State private var session: LanguageModelSession?
    
    // 同一份“文档 + 意图”描述，喂给两种生成方式
    @State private var userText: String = """
    这是一份 2024 年的 IRS 报税表，需要在本周内提交给税务局。
    我打算今晚发传真过去，最好加一页封面说明这是修正申报。
    """
    
    // Generable 输出
    @State private var workflowPlan: DocumentWorkflowPlan?
    
    // Dynamic Schema 输出
    @State private var faxPlan: DynamicFaxPlan?
    
    @State private var isRunning: Bool = false
    @State private var errorMessage: String?
    
    // 运行时动态选项（可以想象为后端下发）
    private let availableFaxNumbers = [
        "+1-555-1001",
        "+1-555-IRS-TAX",
        "+1-555-CLAIMS"
    ]
    
    private let destinationCategories = [
        "IRS",
        "Insurance",
        "Bank",
        "HR Department",
        "Other"
    ]
    
    private let availableActions = [
        "send_now",
        "schedule_for_tonight",
        "save_draft_only"
    ]
    
    var body: some View {
        Form {
            Section("Model Availability") {
                Text(systemModel.availability.description)
                    .font(.footnote)
            }
            
            // 输入
            Section("统一输入（OCR 文本 / 文档描述）") {
                TextEditor(text: $userText)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2))
                    )
                
                Text("下面会用同一段输入，分别生成：\n1）通用工作流计划（Generable）\n2）在动态选项内做出的发送计划（Dynamic schema）")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 触发按钮
            Section("Run both generations") {
                Button {
                    Task { await runBothGenerations() }
                } label: {
                    HStack {
                        if isRunning { ProgressView() }
                        Text("同时生成（Generable + DynamicSchema）")
                    }
                }
                .disabled(isRunning || userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            
            // 结果 1：Generable
            if let plan = workflowPlan {
                Section("① Generable 结果：DocumentWorkflowPlan") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📄 标题：\(plan.title)")
                        Text("🗂 文档类型：\(plan.documentType)")
                        Text("🎯 用途：\(plan.purposeSummary)")
                        Text("🔒 敏感信息：\(plan.containsSensitiveData ? "是" : "否")")
                        Text("⏱ 紧急程度：\(plan.urgencyScore)/5")
                        
                        Divider().padding(.vertical, 4)
                        Text("📷 扫描建议：\(plan.recommendedColorMode)，\(plan.recommendedDPI) DPI")
                        Text("📦 压缩 PDF：\(plan.shouldCompressPDF ? "是" : "否")")
                        
                        Divider().padding(.vertical, 4)
                        Text("📠 传真建议：\(plan.suitableForFax ? "适合传真" : "不推荐传真")，预估 \(plan.estimatedFaxPages) 页")
                        Text("📄 封面页：\(plan.shouldAddFaxCover ? "建议添加" : "可选")")
                        
                        if !plan.nextActions.isEmpty {
                            Divider().padding(.vertical, 4)
                            Text("✅ 下一步行动（模型可以自由想）：")
                                .font(.subheadline.bold())
                            ForEach(plan.nextActions, id: \.identifier) { action in
                                Text("• \(action.title) － \(action.rationale)")
                                    .font(.footnote)
                            }
                        }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // 结果 2：Dynamic Schema
            if let faxPlan {
                Section("② DynamicGenerationSchema 结果：DynamicFaxPlan") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📠 fromNumber（只能从运行时列表中选）：\(faxPlan.fromNumber)")
                        Text("🎯 destinationCategory（动态枚举）：\(faxPlan.destinationCategory)")
                        Text("⚙️ action（动态动作枚举）：\(humanReadableAction(faxPlan.action))")
                        Text("📄 addCoverPage：\(faxPlan.addCoverPage ? "是" : "否")")
                        Text("🔥 priority（1~3 范围约束）：\(faxPlan.priority)")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("可以看到：这里的字段值完全被 runtime schema 限制住，模型不能发明新的号码 / 动作，只能在后端给的选项里挑。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Generable vs DynamicSchema")
    }
    
    // MARK: - 逻辑：同时跑两种生成 ------------------------------
    
    private func ensureSessionIfNeeded() {
        guard session == nil else { return }
        
        let instructions = Instructions {
            """
            You are an on-device assistant for Scan / Fax.

            You will receive an OCR text or document description.
            You MUST:
            1) Fill a DocumentWorkflowPlan (Generable) to describe the overall workflow.
            2) When asked with a schema, fill a FaxSendPlan by choosing ONLY values
               allowed by the dynamic schema (fax numbers, actions, etc.)
            """
        }
        
        session = LanguageModelSession(
            model: systemModel,
            instructions: instructions
        )
    }
    
    private func runBothGenerations() async {
        guard systemModel.availability == .available else {
            errorMessage = "SystemLanguageModel 不可用，请在设置里开启 Apple Intelligence。"
            return
        }
        
        ensureSessionIfNeeded()
        guard let session else { return }
        
        isRunning = true
        errorMessage = nil
        workflowPlan = nil
        faxPlan = nil
        
        do {
            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.0,
                maximumResponseTokens: 512
            )
            
            // ① Generable：DocumentWorkflowPlan
            let workflowResponse = try await session.respond(
                to: """
                    Analyze the following document and produce a DocumentWorkflowPlan.

                    Text:
                    \(userText)
                    """,
                generating: DocumentWorkflowPlan.self,
                options: options
            )
            
            self.workflowPlan = workflowResponse.content
            
            // ② Dynamic schema：与 DynamicGenerationSchemaDemoView 类似
            let dynamicFaxPlan = try await generateDynamicFaxPlan(
                session: session,
                userText: userText,
                options: options
            )
            self.faxPlan = dynamicFaxPlan
            
        } catch {
            self.errorMessage = "生成失败：\(error.localizedDescription)"
        }
        
        isRunning = false
    }
    
    // 单独封装 dynamic schema 的部分，基本沿用你之前 Demo 的逻辑
    private func generateDynamicFaxPlan(
        session: LanguageModelSession,
        userText: String,
        options: GenerationOptions
    ) async throws -> DynamicFaxPlan {
        
        // 动态枚举 schemas
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
        
        // 基本类型 schema
        let addCoverSchema = DynamicGenerationSchema(type: Bool.self)
        let prioritySchema = DynamicGenerationSchema(
            type: Int.self,
            guides: [GenerationGuide.range(1...3)]
        )
        
        // root 对象
        let root = DynamicGenerationSchema(
            name: "FaxSendPlan",
            description: "A plan describing how to send or store the current document.",
            properties: [
                .init(name: "fromNumber",
                      description: "Which fax line to use.",
                      schema: DynamicGenerationSchema(referenceTo: "FromNumber")),
                .init(name: "destinationCategory",
                      description: "Receiver category.",
                      schema: DynamicGenerationSchema(referenceTo: "DestinationCategory")),
                .init(name: "action",
                      description: "What to do with this document.",
                      schema: DynamicGenerationSchema(referenceTo: "Action")),
                .init(name: "addCoverPage",
                      description: "Whether to include a cover page.",
                      schema: addCoverSchema),
                .init(name: "priority",
                      description: "Priority 1~3.",
                      schema: prioritySchema)
            ]
        )
        
        let generationSchema = try GenerationSchema(
            root: root,
            dependencies: [fromNumberEnum, destinationEnum, actionEnum]
        )
        
        let generated = try await session.respond(
            to: """
                Based on the user's description, choose the best fax plan.
                """,
            schema: generationSchema,
            options: options
        ).content
        
        let fromNumber = try generated.value(String.self, forProperty: "fromNumber")
        let dest = try generated.value(String.self, forProperty: "destinationCategory")
        let action = try generated.value(String.self, forProperty: "action")
        let addCover = try generated.value(Bool.self, forProperty: "addCoverPage")
        let priority = try generated.value(Int.self, forProperty: "priority")
        
        return DynamicFaxPlan(
            fromNumber: fromNumber,
            destinationCategory: dest,
            action: action,
            addCoverPage: addCover,
            priority: priority
        )
    }
    
    private func humanReadableAction(_ action: String) -> String {
        switch action {
        case "send_now":             return "立即发送传真"
        case "schedule_for_tonight": return "今晚定时发送"
        case "save_draft_only":      return "仅保存草稿"
        default:                     return action
        }
    }
}

// 小工具：打印 availability（你之前的 extension 可以复用）
@available(iOS 18.0, macOS 15.0, *)
private extension SystemLanguageModel.Availability {
    var description: String {
        switch self {
        case .available:                 "✅ available"
        case .unavailable(let reason):   "❌ \(String(describing: reason))"
        }
    }
}
