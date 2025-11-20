//
//  DemoContact.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


//
//  DynamicContactSelectionDemoView.swift
//  AIEngineApp
//
//  场景 4：动态联系人结构（动态 object + array）
//  - 模拟通讯录联系人：[ { name, numbers: [String] } ]
//  - 使用 DynamicGenerationSchema 构造 Contact（带 numbers 数组）
//  - 让模型在这些联系人里选一个“最适合发传真的人 + 号码”，并给出中文解释
//

import SwiftUI
import Foundation
import FoundationModels

// MARK: - 模拟通讯录联系人 -----------------------------------------------------------

struct DemoContact: Identifiable, Equatable {
    let id: UUID = UUID()
    let name: String
    let numbers: [String]
    let role: String          // 业务角色：会计、律师、保险代理等
    let notes: String         // 备注，用来指导模型选择
}

struct FaxContactSelectionResult {
    let contactName: String
    let selectedNumber: String
    let reason: String
}

@MainActor
struct DynamicContactSelectionDemoView: View {
    
    // MARK: - Apple Intelligence
    
    private let systemModel = SystemLanguageModel.default
    @State private var session: LanguageModelSession?
    
    // MARK: - 模拟通讯录列表（可以想象成从 CNContact / 后端转换而来）
    
    private let contacts: [DemoContact] = [
        DemoContact(
            name: "Alex Chen",
            numbers: ["+1 415-555-2000", "+1 415-555-9000"],
            role: "美国注册会计师（CPA）",
            notes: "主要帮我处理美国 IRS & 州税相关的报税业务，经常用传真收 IRS 表格。"
        ),
        DemoContact(
            name: "Emily Zhang",
            numbers: ["+1 650-555-3333"],
            role: "移民律师",
            notes: "主要帮我处理移民材料、签证续签，偶尔需要传真 USCIS 表格。"
        ),
        DemoContact(
            name: "Global Tax Service",
            numbers: ["+1 800-555-8888", "+1 800-555-7777"],
            role: "大型报税公司前台",
            notes: "通用客服电话，内部会再转给不同部门，用传真收件效率比较一般。"
        ),
        DemoContact(
            name: "Bank of Silicon Valley – Mortgage",
            numbers: ["+1 408-555-1234"],
            role: "房贷专员",
            notes: "主要处理房贷合同、银行对账单，习惯通过安全消息 / 邮件，不太常用传真。"
        )
    ]
    
    // MARK: - 用户输入 & 状态
    
    @State private var userFaxGoal: String = """
    我需要给美国的会计发送一份 2024 年的 IRS 报税表和相关收据，希望对方能尽快收到并处理。
    最好选一个常用的工作传真号码，不要选通用客服电话那种。
    """
    
    @State private var isRunning: Bool = false
    @State private var errorMessage: String?
    
    @State private var selectionResult: FaxContactSelectionResult?
    @State private var rawGeneratedDebug: String?
    
    var body: some View {
        Form {
            // 模型可用性
            Section("Model Availability") {
                Text(systemModel.availability.description)
                    .font(.footnote)
                    .foregroundColor(systemModel.availability == .available ? .green : .red)
            }
            
            // 通讯录列表展示
            Section("通讯录（模拟数据）") {
                ForEach(contacts) { contact in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(contact.name)
                            .font(.headline)
                        Text(contact.role)
                            .font(.subheadline)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("号码：")
                                .font(.subheadline).bold()
                            ForEach(contact.numbers, id: \.self) { num in
                                Text("• \(num)")
                                    .font(.caption)
                            }
                        }
                        Text("备注：\(contact.notes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Text("这里相当于你从 CNContact / 后端转换后的精简结构：name + [numbers] + 业务角色描述。DynamicGenerationSchema 只关心结构，具体联系人列表通过 prompt 传给模型。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 用户传真需求描述
            Section("传真需求描述（输入给模型）") {
                TextEditor(text: $userFaxGoal)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2))
                    )
                
                Text("建议用户写清楚：要 fax 给谁（会计 / 律师 / 银行）、用途（IRS 报税 / 移民材料）、是否紧急等。模型会结合通讯录信息选择最合适的联系人 + 号码。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 触发生成
            Section("让模型从通讯录里挑一个最适合发传真的人") {
                Button {
                    Task { await runContactSelection() }
                } label: {
                    HStack {
                        if isRunning { ProgressView() }
                        Text("选择联系人 & 号码（DynamicGenerationSchema）")
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
            if let selectionResult {
                Section("推荐结果") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("推荐联系人")
                            .font(.headline)
                        Text(selectionResult.contactName)
                            .font(.title3)
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("推荐传真号码")
                            .font(.headline)
                        Text(selectionResult.selectedNumber)
                            .font(.title3)
                        
                        Divider().padding(.vertical, 4)
                        
                        Text("模型解释（为什么这样选）")
                            .font(.headline)
                        Text(selectionResult.reason)
                            .font(.subheadline)
                    }
                }
            }
            
            // 调试信息：GeneratedContent 的结构
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
        .navigationTitle("动态联系人选择（传真）")
    }
    
    // MARK: - Session & 调用逻辑 -----------------------------------------------------
    
    private func ensureSessionIfNeeded() {
        guard session == nil else { return }
        
        let instructions = Instructions {
            """
            You are an on-device assistant inside the Fax / Jet Scan app.

            The app will give you:
            1. A list of contacts (name, phone numbers, business role, notes).
            2. A natural language description of the user's fax goal (in Chinese).

            Your task:
            - From the provided contacts, choose ONE person who is most appropriate to receive the fax.
            - Choose ONE phone number for faxing (prefer a direct work fax over generic call center).
            - Explain your reasoning in Chinese.

            You MUST:
            - Only select a name and phone number that exist in the provided contact list.
            """
        }
        
        session = LanguageModelSession(
            model: systemModel,
            instructions: instructions
        )
    }
    
    private func runContactSelection() async {
        guard systemModel.availability == .available else {
            errorMessage = "SystemLanguageModel 不可用，请在设置中开启 Apple Intelligence。"
            return
        }
        
        ensureSessionIfNeeded()
        guard let session else { return }
        
        isRunning = true
        errorMessage = nil
        selectionResult = nil
        rawGeneratedDebug = nil
        
        do {
            // 1. 定义「电话数组」的动态 schema：numbers: [String]，至少 1 个
            let phoneArraySchema = DynamicGenerationSchema(
                arrayOf: DynamicGenerationSchema(type: String.self),
                minimumElements: 1
            )
            
            // 2. 定义 Contact 对象 schema：name + numbers
            let contactSchema = DynamicGenerationSchema(
                name: "Contact",
                description: "A simple contact with name and phone numbers.",
                properties: [
                    .init(
                        name: "name",
                        description: "Contact display name.",
                        schema: DynamicGenerationSchema(type: String.self)
                    ),
                    .init(
                        name: "numbers",
                        description: "Phone numbers for this contact.",
                        schema: phoneArraySchema
                    )
                ]
            )
            
            // （可选）定义 “在这些联系人中选择一个” 的结果 schema
            // 这里只让模型输出一个结构化结果：选中的联系人名、号码、解释原因
            let selectionSchema = DynamicGenerationSchema(
                name: "FaxContactSelection",
                description: "Result of selecting one contact for fax.",
                properties: [
                    .init(
                        name: "chosenContact",
                        description: "The chosen contact object.",
                        schema: DynamicGenerationSchema(referenceTo: "Contact")
                    ),
                    .init(
                        name: "selectedNumber",
                        description: "The phone number chosen for fax.",
                        schema: DynamicGenerationSchema(type: String.self)
                    ),
                    .init(
                        name: "reason",
                        description: "Explanation in Chinese of why this contact and number were chosen.",
                        schema: DynamicGenerationSchema(type: String.self)
                    )
                ]
            )
            
            // 3. 构建 GenerationSchema（root 是选择结果，依赖里包含 Contact）
            let generationSchema = try GenerationSchema(
                root: selectionSchema,
                dependencies: [contactSchema]
            )
            
            // 4. 把通讯录联系人转成一段文本描述给模型
            let contactsText = contacts
                .enumerated()
                .map { index, c -> String in
                    let numbersText = c.numbers.joined(separator: ", ")
                    return """
                    [\(index + 1)] \(c.name)
                    - 角色：\(c.role)
                    - 电话：\(numbersText)
                    - 备注：\(c.notes)
                    """
                }
                .joined(separator: "\n\n")
            
            let prompt = """
            下面是当前通讯录中可以发送传真的一些联系人：

            \(contactsText)

            用户的传真需求描述如下：
            \(userFaxGoal)

            请根据用户需求，从以上联系人中挑选一个最合适接收传真的人：
            - 选出一个联系人（必须来自列表）
            - 选出一个最合适的号码用于传真（必须来自该联系人号码列表）
            - 用中文解释你为什么选择这个人和这个号码（比如：角色匹配、是否常用、是否为前台等）
            """
            
            let options = GenerationOptions(
                sampling: .greedy,          // 结构化输出优先稳定
                temperature: 0.0,
                maximumResponseTokens: 256
            )
            
            // 5. 调用模型，使用 DynamicGenerationSchema 约束输出结构
            let generatedContent = try await session.respond(
                to: prompt,
                schema: generationSchema,
                options: options
            ).content
            
            // 6. 从 GeneratedContent 中解析结构化结果
            // chosenContact 是一个嵌套的 Contact 对象
            let chosenContactContent = try generatedContent.value(
                GeneratedContent.self,
                forProperty: "chosenContact"
            )
            
            let chosenName = try chosenContactContent.value(
                String.self,
                forProperty: "name"
            )
            let selectedNumber = try generatedContent.value(
                String.self,
                forProperty: "selectedNumber"
            )
            let reason = try generatedContent.value(
                String.self,
                forProperty: "reason"
            )
            
            self.selectionResult = FaxContactSelectionResult(
                contactName: chosenName,
                selectedNumber: selectedNumber,
                reason: reason
            )
            
            self.rawGeneratedDebug = generatedContent.debugDescription.description
            
        } catch {
            self.errorMessage = "生成失败：\(error.localizedDescription)"
        }
        
        isRunning = false
    }
}

// MARK: - Availability 描述（和前面 Demo 同风格）

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
