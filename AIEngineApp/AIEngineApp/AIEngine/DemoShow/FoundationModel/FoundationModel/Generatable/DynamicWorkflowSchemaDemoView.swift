//
//  WorkflowStepResult.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


//
//  DynamicWorkflowSchemaDemoView.swift
//  AIEngineApp
//
//  场景 6：复杂工作流（object + array + references）
//  - 目标：让模型根据用户描述，生成“扫描 → OCR → 压缩 → 传真”的动态步骤列表。
//  - 使用 DynamicGenerationSchema 构造：
//    * WorkflowAction: ["scan","ocr","compress","fax"]
//    * WorkflowStep: { action, confidence(0~1), notes? }
//    * steps: [WorkflowStep] (1~10 步)
//    * DynamicWorkflow: { steps, summary }
//
//  完整演示：object + array + referenceTo + Double range + optional 字段
//

import SwiftUI
import Foundation
import FoundationModels

// MARK: - UI 用的结果模型 ------------------------------------------------------------

struct WorkflowStepResult: Identifiable, Equatable {
    let id = UUID()
    let action: String
    let confidence: Double
    let notes: String?
}

struct DynamicWorkflowResult: Equatable {
    let steps: [WorkflowStepResult]
    let summary: String
}

@MainActor
struct DynamicWorkflowSchemaDemoView: View {
    
    // MARK: - Apple Intelligence
    
    private let systemModel = SystemLanguageModel.default
    @State private var session: LanguageModelSession?
    
    // MARK: - 用户输入：文档 & 业务目标描述 -------------------------------------------
    
    @State private var userDocumentDescription: String = """
    我刚刚从手机相册里选了一份 12 页的 PDF，主要是 2024 年美国报税相关材料：
    - 包含 W-2、1099、银行对账单
    - 上面有很多数字和小字
    - 最终我要发传真给税务会计，作为报税准备材料

    帮我规划一个合理的“扫描 → OCR → 压缩 → 传真”工作流：
    - 先考虑是否需要重新扫描（比如原始是照片）
    - 然后做 OCR 提取文字
    - 再做 PDF 压缩（保证可读性）
    - 最后发传真（可以附带简单的封面信息）
    """
    
    @State private var isRunning: Bool = false
    @State private var errorMessage: String?
    
    @State private var workflowResult: DynamicWorkflowResult?
    @State private var rawGeneratedDebug: String?
    
    var body: some View {
        Form {
            // 模型可用性
            Section("Model Availability") {
                Text(systemModel.availability.description)
                    .font(.footnote)
                    .foregroundColor(systemModel.availability == .available ? .green : .red)
            }
            
            // 用户输入：文档 & 目标描述
            Section("文档 & 业务目标描述（输入给模型）") {
                TextEditor(text: $userDocumentDescription)
                    .frame(minHeight: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2))
                    )
                
                Text("""
                建议用户写清楚：
                - 文档类型：合同 / 报税表 / 收据 / 医疗材料…
                - 页数、清晰度要求、是否有照片。
                - 业务目标：发给谁？IRS / 会计 / 律师？
                - 是否需要后续再签名、再次传真等。
                模型会根据这些信息规划一个步骤列表。
                """)
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            // 触发生成
            Section("生成“扫描 → OCR → 压缩 → 传真”工作流（DynamicGenerationSchema）") {
                Button {
                    Task { await runWorkflowGeneration() }
                } label: {
                    HStack {
                        if isRunning { ProgressView() }
                        Text("生成动态工作流")
                    }
                }
                .disabled(isRunning)
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            
            // 结果展示：工作流步骤
            if let workflowResult {
                Section("生成的工作流步骤（steps: [WorkflowStep]）") {
                    if workflowResult.steps.isEmpty {
                        Text("模型没有返回任何步骤。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(workflowResult.steps.enumerated()), id: \.1.id) { index, step in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Step \(index + 1)")
                                        .font(.headline)
                                    Spacer()
                                    Text(step.action.uppercased())
                                        .font(.subheadline)
                                        .padding(4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                
                                HStack {
                                    Text("置信度：")
                                        .font(.subheadline)
                                    Text(String(format: "%.2f", step.confidence))
                                        .font(.subheadline)
                                }
                                
                                if let notes = step.notes, !notes.isEmpty {
                                    Text("说明：\(notes)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Text("""
                        action 只允许为：
                        - scan：重新拍照 / 扫描
                        - ocr：文字识别
                        - compress：PDF 压缩
                        - fax：准备传真 & 发送
                        confidence 在 [0,1] 之间，由 DynamicGenerationSchema + GenerationGuide.range 约束。
                        """)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                }
                
                // 结果展示：summary
                Section("工作流总结（summary）") {
                    Text(workflowResult.summary)
                        .font(.subheadline)
                }
            }
            
            // 调试：GeneratedContent 原始结构
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
        .navigationTitle("动态工作流（scan→ocr→compress→fax）")
    }
    
    // MARK: - Session & 调用逻辑 -----------------------------------------------------
    
    private func ensureSessionIfNeeded() {
        guard session == nil else { return }
        
        let instructions = Instructions {
            """
            You are an on-device assistant inside the Scan / Fax app.

            The app will give you:
            1. A description of the current document and business goal (in Chinese).
            2. You must design a step-by-step workflow using only these actions:
               - scan
               - ocr
               - compress
               - fax

            Your task:
            - Generate a DynamicWorkflow with:
              * steps: an ordered list of WorkflowStep
              * summary: a short Chinese explanation of the whole workflow.
            - For each step:
              * action must be one of "scan", "ocr", "compress", "fax".
              * confidence is a number in [0.0, 1.0] indicating how appropriate this step is.
              * notes (optional) should explain what to do in this step (in Chinese),
                e.g. preferred scan preset, OCR languages, compression goal, fax target, etc.

            You MUST:
            - Use at least 1 step, and at most 10 steps.
            - Steps should be in logical order (e.g. scan -> ocr -> compress -> fax).
            - If some steps can be skipped, reflect that in confidence or in notes.
            """
        }
        
        session = LanguageModelSession(
            model: systemModel,
            instructions: instructions
        )
    }
    
    private func runWorkflowGeneration() async {
        guard systemModel.availability == .available else {
            errorMessage = "SystemLanguageModel 不可用，请在设置中开启 Apple Intelligence。"
            return
        }
        
        ensureSessionIfNeeded()
        guard let session else { return }
        
        isRunning = true
        errorMessage = nil
        workflowResult = nil
        rawGeneratedDebug = nil
        
        do {
            // 1. 动作类型枚举（字符串 anyOf）
            let actionEnum = DynamicGenerationSchema(
                name: "WorkflowAction",
                description: "Workflow action type.",
                anyOf: ["scan", "ocr", "compress", "fax"]
            )
            
            // 2. WorkflowStep object：action + confidence(0~1) + notes?
            let stepSchema = DynamicGenerationSchema(
                name: "WorkflowStep",
                description: "Single workflow step.",
                properties: [
                    .init(
                        name: "action",
                        description: "Action type: scan / ocr / compress / fax.",
                        schema: DynamicGenerationSchema(referenceTo: "WorkflowAction")
                    ),
                    .init(
                        name: "confidence",
                        description: "Confidence score between 0.0 and 1.0.",
                        schema: DynamicGenerationSchema(
                            type: Double.self,
                            guides: [GenerationGuide.range(0.0...1.0)]
                        )
                    ),
                    .init(
                        name: "notes",
                        description: "Optional Chinese notes for this step.",
                        schema: DynamicGenerationSchema(type: String.self),
                        isOptional: true
                    )
                ]
            )
            
            // 3. steps: [WorkflowStep] (1~10 步)
            let workflowArray = DynamicGenerationSchema(
                arrayOf: DynamicGenerationSchema(referenceTo: "WorkflowStep"),
                minimumElements: 1,
                maximumElements: 10
            )
            
            // 4. DynamicWorkflow 根 schema
            let workflowSchema = DynamicGenerationSchema(
                name: "DynamicWorkflow",
                description: "Dynamic workflow for scan → ocr → compress → fax.",
                properties: [
                    .init(
                        name: "steps",
                        description: "Ordered workflow steps.",
                        schema: workflowArray
                    ),
                    .init(
                        name: "summary",
                        description: "Chinese summary of the whole workflow.",
                        schema: DynamicGenerationSchema(type: String.self)
                    )
                ]
            )
            
            // 5. 构建 GenerationSchema：根是 DynamicWorkflow，依赖包含 WorkflowAction / WorkflowStep
            let generationSchema = try GenerationSchema(
                root: workflowSchema,
                dependencies: [actionEnum, stepSchema]
            )
            
            // 6. prompt：目前只需要用户描述（文档 + 目标）
            let prompt = """
            用户当前的文档和业务需求描述如下：
            \(userDocumentDescription)

            请根据用户描述，设计一个合理的“扫描 → OCR → 压缩 → 传真”工作流：
            - 只允许使用以下动作：scan, ocr, compress, fax
            - 注意区分：何时需要重新扫描、OCR 的目的、压缩目标、传真目标对象
            - 动作顺序要符合实际使用逻辑
            - 每一步需要一个置信度（0.0~1.0），表示这一步在当前场景下的重要程度
            - 可在 notes 中用中文解释细节（比如推荐使用的扫描预设、OCR 语言、压缩大小等）

            最终输出必须符合 DynamicWorkflow 的结构。
            """
            
            let options = GenerationOptions(
                sampling: .greedy,   // 结构化输出优先稳定
                temperature: 0.0,
                maximumResponseTokens: 512
            )
            
            // 7. 调用模型，使用动态 schema 限制输出结构
            let generatedContent = try await session.respond(
                to: prompt,
                schema: generationSchema,
                options: options
            ).content
            
            // 8. 从 GeneratedContent 中解析结果 ----------------------------
            
            // steps: [WorkflowStep]
            let stepsContentArray = try generatedContent.value(
                [GeneratedContent].self,
                forProperty: "steps"
            )
            
            let parsedSteps: [WorkflowStepResult] = try stepsContentArray.map { stepContent in
                let action = try stepContent.value(String.self, forProperty: "action")
                let confidence = try stepContent.value(Double.self, forProperty: "confidence")
                
                // notes 是 optional，解析失败时可以返回 nil
                let notes: String?
                do {
                    notes = try stepContent.value(String.self, forProperty: "notes")
                } catch {
                    notes = nil
                }
                
                return WorkflowStepResult(
                    action: action,
                    confidence: confidence,
                    notes: notes
                )
            }
            
            let summary = try generatedContent.value(
                String.self,
                forProperty: "summary"
            )
            
            self.workflowResult = DynamicWorkflowResult(
                steps: parsedSteps,
                summary: summary
            )
            
            self.rawGeneratedDebug = generatedContent.debugDescription.description
            
        } catch {
            self.errorMessage = "生成失败：\(error.localizedDescription)"
        }
        
        isRunning = false
    }
}

// MARK: - Availability 描述（和其他 Demo 统一风格）

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
