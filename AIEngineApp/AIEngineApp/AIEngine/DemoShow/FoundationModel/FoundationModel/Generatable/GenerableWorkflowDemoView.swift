import SwiftUI
import Foundation
import FoundationModels

@MainActor
struct GenerableWorkflowDemoView: View {
    
    private let systemModel = SystemLanguageModel.default
    
    @State private var session: LanguageModelSession?
    
    @State private var selectedScenario: GenerableDemoScenario = .taxForm
    @State private var ocrText: String = GenerableDemoScenario.taxForm.sampleOCRText
    
    @State private var isRunning: Bool = false
    @State private var lastPlan: DocumentWorkflowPlan?
    @State private var errorMessage: String?
    
    // 为这个 Demo 定制的 Instructions：告诉模型“你是 Jet Scan/Fax 工作流助手”
    private var instructions: Instructions {
        Instructions {
            """
            You are an on-device AI assistant for Scan and Fax.
            You receive OCR text or a short description of a document.
            Your job is NOT to write a long essay, but to fill in a structured
            Swift type called DocumentWorkflowPlan.

            Be conservative when marking documents as containing sensitive data.
            If the text includes tax IDs, bank details, medical info, or legal
            contracts, mark containsSensitiveData as true.

            Use urgencyScore to reflect how time sensitive the document is for the user.
            For example, tax forms close to a deadline or urgent medical records should
            have higher urgency.

            In addition to basic fields, also:
            - Set confidenceScore between 0.0 and 1.0 to indicate how confident you are.
            - Fill keyFields with important extracted values like name, ID, total amount.
            - Set imageCleanupChecklist with steps like "deskew", "remove_background", "enhance_edges" if needed.
            - Use warnings and potentialErrors to point out issues before sending or storing the document.
            - Propose a small list of pipelineSteps like OCR, enhance image, compress PDF, send fax, save to cloud.
            - Provide clear nextActions that are practical for end users.
            """
        }
    }
    
    var body: some View {
        Form {
            // 1. 模型可用性
            Section("Model Availability") {
                AvailabilityRow(availability: systemModel.availability)
            }
            
            // 2. 场景 + 输入
            Section("Input: OCR 文本 / 文档描述") {
                Picker("Preset scenario", selection: $selectedScenario) {
                    ForEach(GenerableDemoScenario.allCases) { scenario in
                        Text(scenario.title).tag(scenario)
                    }
                }
                .onChange(of: selectedScenario) { newValue in
                    ocrText = newValue.sampleOCRText
                    lastPlan = nil
                    errorMessage = nil
                }
                
                TextEditor(text: $ocrText)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2))
                    )
                
                Text("""
                你可以把真正的 OCR 文本粘贴到这里，让模型给你一个结构化“工作流计划”对象：
                - 文档类型 / 用途 / 紧急程度
                - 扫描 & 传真建议
                - 关键字段（姓名、金额、ID 等）
                - 风险 & 警告
                - 自动化 Pipeline 步骤 + 下一步行动
                """)
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            // 3. 触发生成
            Section("Generate") {
                Button {
                    Task { await runGeneration() }
                } label: {
                    HStack {
                        if isRunning { ProgressView() }
                        Text("生成 DocumentWorkflowPlan（Generable）")
                    }
                }
                .disabled(isRunning || ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                if let message = errorMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            
            // 4. 结果展示：结构化对象，而不是原始字符串
            if let plan = lastPlan {
                Section("Result: 结构化工作流计划 (DocumentWorkflowPlan)") {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            
                            // MARK: - 文档概览
                            Group {
                                Text("📄 文档概览")
                                    .font(.headline)
                                Text("标题：\(plan.title)")
                                Text("类型：\(plan.documentType)")
                                Text("用途：\(plan.purposeSummary)")
                                Text("敏感信息：\(plan.containsSensitiveData ? "是" : "否")")
                                Text("紧急程度：\(plan.urgencyScore)/5")
                                Text(String(format: "模型信心：%.0f%%", plan.confidenceScore * 100))
                            }
                            .font(.subheadline)
                            
                            Divider().padding(.vertical, 4)
                            
                            // MARK: - 结构分析 & 关键字段
                            Group {
                                Text("📚 文档结构 & 关键字段")
                                    .font(.headline)
                                
                                Text("检测到的段落数量（sections）：\(plan.sectionCount)")
                                    .font(.subheadline)
                                
                                if !plan.keyFields.isEmpty {
                                    Text("关键字段：")
                                        .font(.subheadline.bold())
                                        .padding(.top, 2)
                                    
                                    ForEach(plan.keyFields, id: \.fieldName) { field in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("• \(field.fieldName)：\(field.fieldValue)")
                                                .font(.subheadline)
                                            if field.isSensitive {
                                                Text("包含敏感信息")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                } else {
                                    Text("未找到明显的关键字段。")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider().padding(.vertical, 4)
                            
                            // MARK: - 扫描建议
                            Group {
                                Text("📷 扫描建议")
                                    .font(.headline)
                                
                                Text("颜色模式：\(plan.recommendedColorMode)")
                                Text("分辨率：\(plan.recommendedDPI) DPI")
                                Text("是否压缩 PDF：\(plan.shouldCompressPDF ? "是，优先压缩体积" : "否，优先保持清晰度")")
                                
                                if !plan.imageCleanupChecklist.isEmpty {
                                    Text("图像清理步骤：")
                                        .font(.subheadline.bold())
                                        .padding(.top, 2)
                                    
                                    ForEach(plan.imageCleanupChecklist, id: \.self) { item in
                                        Text("• \(item)")
                                            .font(.subheadline)
                                    }
                                }
                            }
                            .font(.subheadline)
                            
                            Divider().padding(.vertical, 4)
                            
                            // MARK: - 传真建议
                            Group {
                                Text("📠 传真建议")
                                    .font(.headline)
                                
                                Text("是否适合传真：\(plan.suitableForFax ? "适合" : "不建议")")
                                Text("预估传真页数：\(plan.estimatedFaxPages) 页")
                                Text("传真优先级：\(plan.faxPriority)（1 = 普通，3 = 最高）")
                                Text("是否建议加封面页：\(plan.shouldAddFaxCover ? "建议" : "可选")")
                            }
                            .font(.subheadline)
                            
                            Divider().padding(.vertical, 4)
                            
                            // MARK: - 风险 & 潜在错误
                            Group {
                                Text("⚠️ 风险 & 潜在问题")
                                    .font(.headline)
                                
                                if !plan.warnings.isEmpty {
                                    Text("Warnings：")
                                        .font(.subheadline.bold())
                                    ForEach(plan.warnings, id: \.self) { w in
                                        Text("• \(w)")
                                            .font(.subheadline)
                                    }
                                }
                                
                                if !plan.potentialErrors.isEmpty {
                                    Text("Potential Errors：")
                                        .font(.subheadline.bold())
                                        .padding(.top, 4)
                                    ForEach(plan.potentialErrors, id: \.self) { e in
                                        Text("• \(e)")
                                            .font(.subheadline)
                                    }
                                }
                                
                                if plan.warnings.isEmpty && plan.potentialErrors.isEmpty {
                                    Text("当前未发现明显风险。")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider().padding(.vertical, 4)
                            
                            // MARK: - Pipeline 步骤
                            Group {
                                Text("🧬 自动化 Pipeline 步骤")
                                    .font(.headline)
                                
                                if !plan.pipelineSteps.isEmpty {
                                    ForEach(plan.pipelineSteps, id: \.identifier) { step in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("• [\(step.identifier)] \(step.title)")
                                                .font(.subheadline)
                                            Text(step.rationale)
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                } else {
                                    Text("暂无自动化步骤建议。")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider().padding(.vertical, 4)
                            
                            // MARK: - 下一步行动建议（面向用户）
                            if !plan.nextActions.isEmpty {
                                Group {
                                    Text("✅ 下一步行动建议（用户可见）")
                                        .font(.headline)
                                    
                                    ForEach(plan.nextActions, id: \.identifier) { action in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("• \(action.title)")
                                                .font(.subheadline)
                                            Text(action.rationale)
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 400) // 避免拉得太长，可以按需要调整
                }
            }
        }
        .navigationTitle("Generable Demo (Workflow)")
    }
        
    private func ensureSessionIfNeeded() {
        guard session == nil else { return }
        session = LanguageModelSession(
            model: systemModel,
            instructions: instructions
        )
    }
    
    private func runGeneration() async {
        guard systemModel.availability == .available else {
            await MainActor.run {
                errorMessage = "SystemLanguageModel 不可用，请在设置中开启 Apple Intelligence。"
            }
            return
        }
        
        await MainActor.run {
            isRunning = true
            errorMessage = nil
        }
        
        ensureSessionIfNeeded()
        guard let session else { return }
        
        do {
            let options = GenerationOptions(
                sampling: .greedy,      // 结构化输出，优先稳定
                temperature: 0.0,
                maximumResponseTokens: 512
            )
            
            let plan = try await session.respond(
                to: """
                    Analyze the following OCR text or document description and produce a structured workflow plan.

                    OCR / description:
                    \(ocrText)
                    """,
                generating: DocumentWorkflowPlan.self,
                options: options
            )
            
            await MainActor.run {
                self.lastPlan = plan.content
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "生成失败：\(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isRunning = false
        }
    }
}
