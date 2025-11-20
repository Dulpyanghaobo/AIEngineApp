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
            You are an on-device AI assistant for Jet Scan and Jet Fax.
            You receive OCR text or a short description of a document.
            Your job is NOT to write a long essay, but to fill in a structured
            Swift type called DocumentWorkflowPlan.

            Be conservative when marking documents as containing sensitive data.
            If the text includes tax IDs, bank details, medical info, or legal
            contracts, mark containsSensitiveData as true.

            Use urgencyScore to reflect how time sensitive the document is for the user.
            For example, tax forms close to a deadline or urgent medical records should
            have higher urgency.

            Recommend scan and fax settings based on document type, and provide a few
            clear nextActions that are practical for end users.
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
                
                Text("你可以把真正的 OCR 文本粘贴到这里，让模型给你一个结构化“工作流计划”对象。")
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
                    VStack(alignment: .leading, spacing: 8) {
                        Group {
                            Text("📄 标题：\(plan.title)")
                            Text("🗂 文档类型：\(plan.documentType)")
                            Text("🎯 用途：\(plan.purposeSummary)")
                            Text("🔒 是否包含敏感信息：\(plan.containsSensitiveData ? "是" : "否")")
                            Text("⏱ 紧急程度：\(plan.urgencyScore)/5")
                        }
                        .font(.subheadline)
                        
                        Divider().padding(.vertical, 4)
                        
                        Group {
                            Text("📷 扫描建议")
                                .font(.subheadline.bold())
                            Text("颜色模式：\(plan.recommendedColorMode)")
                            Text("分辨率：\(plan.recommendedDPI) DPI")
                            Text("是否压缩 PDF：\(plan.shouldCompressPDF ? "是，优先压缩体积" : "否，优先保持清晰度")")
                        }
                        .font(.subheadline)
                        
                        Divider().padding(.vertical, 4)
                        
                        Group {
                            Text("📠 传真建议")
                                .font(.subheadline.bold())
                            Text("是否适合传真：\(plan.suitableForFax ? "适合" : "不建议")")
                            Text("预估传真页数：\(plan.estimatedFaxPages) 页")
                            Text("是否建议加封面页：\(plan.shouldAddFaxCover ? "建议" : "可选")")
                        }
                        .font(.subheadline)
                        
                        Divider().padding(.vertical, 4)
                        
                        if !plan.nextActions.isEmpty {
                            Text("✅ 下一步行动建议")
                                .font(.subheadline.bold())
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
                    .frame(maxWidth: .infinity, alignment: .leading)
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
