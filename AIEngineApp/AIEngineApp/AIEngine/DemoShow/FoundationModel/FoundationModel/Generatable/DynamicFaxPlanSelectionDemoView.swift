//
//  BackendFaxPlan.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//


//
//  DynamicFaxPlanSelectionDemoView.swift
//  AIEngineApp
//
//  场景 1：动态传真套餐推荐（DynamicGenerationSchema + Property）
//  - 模拟后端返回一堆套餐 JSON
//  - 用 DynamicGenerationSchema 在运行时约束模型只能在这些套餐中做选择
//

import SwiftUI
import Foundation
import FoundationModels

// MARK: - 模拟后端返回的套餐模型（纯 Swift，用来展示和对比） -------------------------

struct BackendFaxPlan: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let pagesIncluded: Int
    let recurring: Bool        // true = 订阅（月付/年付），false = 一次性包
    let price: Double
    let currency: String       // USD / CAD / EUR 等
}

// UI 用的结果结构（不需要 Generable）
struct PlanRecommendationResult {
    let selected: BackendFaxPlan?
    let alternatives: [BackendFaxPlan]
    let explanation: String
}

@MainActor
struct DynamicFaxPlanSelectionDemoView: View {
    
    // Apple Intelligence 模型
    private let systemModel = SystemLanguageModel.default
    @State private var session: LanguageModelSession?
    
    // MARK: - 模拟“后端 JSON 返回的当前有效套餐列表”
    
    private let backendPlans: [BackendFaxPlan] = [
        .init(id: "monthly_200",
              name: "Monthly 200 pages",
              pagesIncluded: 200,
              recurring: true,
              price: 9.99,
              currency: "USD"),
        .init(id: "monthly_500",
              name: "Monthly 500 pages",
              pagesIncluded: 500,
              recurring: true,
              price: 17.99,
              currency: "USD"),
        .init(id: "yearly_2000",
              name: "Yearly 2000 pages",
              pagesIncluded: 2000,
              recurring: true,
              price: 129.0,
              currency: "USD"),
        .init(id: "one_time_50",
              name: "One-time 50 pages pack",
              pagesIncluded: 50,
              recurring: false,
              price: 6.99,
              currency: "USD"),
        .init(id: "one_time_150",
              name: "One-time 150 pages pack",
              pagesIncluded: 150,
              recurring: false,
              price: 14.99,
              currency: "USD"),
        .init(id: "monthly_canada_150",
              name: "Monthly 150 pages (Canada only)",
              pagesIncluded: 150,
              recurring: true,
              price: 11.99,
              currency: "CAD")
    ]
    
    // 把上面的 plans 转成 JSON 字符串展示给用户看（模拟后端返回）
    private var backendPlansJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(backendPlans),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }
    
    // MARK: - 用户输入 & 状态
    
    @State private var userNeedDescription: String = """
    我主要在美国本地发传真，每个月大概 120～180 页，
    偶尔会在报税季多发一点，但也不会超过 250 页。
    希望总价格便宜一点，不想一次性付太多钱。
    请用中文帮我挑一个合适的套餐。
    """
    
    @State private var isRunning: Bool = false
    @State private var errorMessage: String?
    @State private var result: PlanRecommendationResult?
    @State private var rawGeneratedDebug: String?
    
    var body: some View {
        Form {
            // 模型可用性
            Section("Model Availability") {
                Text(systemModel.availability.description)
                    .font(.footnote)
                    .foregroundColor(systemModel.availability == .available ? .green : .red)
            }
            
            // 后端 JSON
            Section("模拟后端返回的套餐 JSON") {
                ScrollView {
                    Text(backendPlansJSON)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 140, maxHeight: 220)
                
                Text("这里相当于你的服务器返回的 /plans 接口，数量和内容完全可以在运行时变化。我们不会把这些写死在 Generable 里，而是用 DynamicGenerationSchema 在运行时生成 schema。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 用户需求描述
            Section("用户需求（自然语言）") {
                TextEditor(text: $userNeedDescription)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2))
                    )
                
                Text("可以换成你真实用户的描述，例如：主要给 IRS 报税、偶尔给保险公司发材料、预算多少之类。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // 触发生成
            Section("生成推荐套餐（DynamicGenerationSchema）") {
                Button {
                    Task { await runPlanSelection() }
                } label: {
                    HStack {
                        if isRunning { ProgressView() }
                        Text("让模型在这些套餐中帮我选一档")
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
                if let selected = result.selected {
                    Section("模型推荐的套餐（Selected Plan）") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("✅ \(selected.name)")
                                .font(.headline)
                            Text("ID: \(selected.id)")
                            Text("包含页数：\(selected.pagesIncluded) 页")
                            Text("类型：\(selected.recurring ? "订阅（按期扣费）" : "一次性包")")
                            Text("价格：\(String(format: "%.2f", selected.price)) \(selected.currency)")
                        }
                        .font(.subheadline)
                    }
                } else {
                    Section("模型推荐的套餐（Selected Plan）") {
                        Text("模型返回的 plan id 没有在后端列表里匹配到。")
                            .foregroundColor(.orange)
                    }
                }
                
                if !result.alternatives.isEmpty {
                    Section("候选备选套餐（Alternatives）") {
                        ForEach(result.alternatives) { plan in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• \(plan.name)")
                                Text("  \(plan.pagesIncluded) 页 · \(String(format: "%.2f", plan.price)) \(plan.currency) · \(plan.recurring ? "订阅" : "一次性")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("模型给出的中文解释") {
                    Text(result.explanation)
                        .font(.subheadline)
                }
            }
            
            // 调试：原始 GeneratedContent（可以看到 schema 解析出来的结构）
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
        .navigationTitle("动态传真套餐推荐")
    }
    
    // MARK: - Session / 调用逻辑 ------------------------------------------------
    
    private func ensureSessionIfNeeded() {
        guard session == nil else { return }
        
        let instructions = Instructions {
            """
            You are an on-device assistant inside the Jet Fax app.

            The app will give you:
            1. A list of available fax plans as JSON (coming from backend).
            2. A natural language description of the user's needs (in Chinese).

            Your task:
            - Choose ONE best plan as `selectedPlan`.
            - Optionally provide 0-3 `alternativePlanIds` that might also fit.
            - Explain your reasoning in Chinese as `explanation`.

            You MUST treat the plan list as the source of truth.
            Do NOT invent arbitrary new ids or currencies. The selectedPlan.id
            and all alternativePlanIds MUST be from the provided backend list.
            """
        }
        
        session = LanguageModelSession(
            model: systemModel,
            instructions: instructions
        )
    }
    
    private func runPlanSelection() async {
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
            // 1. 动态枚举：PlanID（只能是后端返回的 id）
            let planIdEnum = DynamicGenerationSchema(
                name: "PlanID",
                description: "Valid backend fax plan identifiers.",
                anyOf: backendPlans.map { $0.id }
            )
            
            // 2. 动态枚举：货币（从后端列表里自动归纳）
            let currencies = Array(Set(backendPlans.map { $0.currency })).sorted()
            let currencyEnum = DynamicGenerationSchema(
                name: "Currency",
                description: "Currencies used by the backend plans.",
                anyOf: currencies
            )
            
            // 3. 对象：价格对象 PlanPrice（使用 Property）
            let priceSchema = DynamicGenerationSchema(
                name: "PlanPrice",
                description: "Price information for a fax plan.",
                properties: [
                    .init(
                        name: "amount",
                        description: "Price value of the plan.",
                        schema: DynamicGenerationSchema(type: Double.self)
                    ),
                    .init(
                        name: "currency",
                        description: "Currency code like USD / CAD / EUR.",
                        schema: DynamicGenerationSchema(referenceTo: "Currency")
                    )
                ]
            )
            
            // 4. 对象：套餐对象 FaxPlan（使用 Property + 引用 PlanID / PlanPrice）
            let faxPlanSchema = DynamicGenerationSchema(
                name: "FaxPlan",
                description: "A fax plan chosen from the backend list.",
                properties: [
                    .init(
                        name: "id",
                        description: "The backend id of the plan.",
                        schema: DynamicGenerationSchema(referenceTo: "PlanID")
                    ),
                    .init(
                        name: "name",
                        description: "Human readable name of the plan.",
                        schema: DynamicGenerationSchema(type: String.self)
                    ),
                    .init(
                        name: "pagesIncluded",
                        description: "How many pages are included.",
                        schema: DynamicGenerationSchema(type: Int.self)
                    ),
                    .init(
                        name: "recurring",
                        description: "true = subscription, false = one-time pack.",
                        schema: DynamicGenerationSchema(type: Bool.self)
                    ),
                    .init(
                        name: "price",
                        description: "Price object of the plan.",
                        schema: DynamicGenerationSchema(referenceTo: "PlanPrice")
                    )
                ]
            )
            
            // 5. Root 对象：PlanRecommendation（里面嵌套 FaxPlan + [PlanID] + explanation）
            let root = DynamicGenerationSchema(
                name: "PlanRecommendation",
                description: "The best plan and alternatives for a given user need.",
                properties: [
                    .init(
                        name: "selectedPlan",
                        description: "The single best plan chosen for the user.",
                        schema: DynamicGenerationSchema(referenceTo: "FaxPlan")
                    ),
                    .init(
                        name: "alternativePlanIds",
                        description: "0-3 alternative plan ids that might also work.",
                        schema: DynamicGenerationSchema(
                            arrayOf: DynamicGenerationSchema(referenceTo: "PlanID"),
                            minimumElements: 0,
                            maximumElements: 3
                        ),
                        isOptional: true
                    ),
                    .init(
                        name: "explanation",
                        description: "Short explanation in Chinese.",
                        schema: DynamicGenerationSchema(type: String.self)
                    )
                ]
            )
            
            // 6. 构建 GenerationSchema（root + 依赖）
            let generationSchema = try GenerationSchema(
                root: root,
                dependencies: [planIdEnum, currencyEnum, priceSchema, faxPlanSchema]
            )
            
            // 7. 调用模型
            let options = GenerationOptions(
                sampling: .greedy,    // 结构化输出，优先稳定
                temperature: 0.0,
                maximumResponseTokens: 256
            )
            
            let prompt = """
            下面是 Jet Fax 后端当前返回的套餐列表（JSON）：
            \(backendPlansJSON)

            用户需求描述：
            \(userNeedDescription)

            请在这些套餐中挑选一个最合适的 selectedPlan，
            可以再给出 0-3 个 alternativePlanIds，并用中文简要解释原因。
            """
            
            let generated: GeneratedContent = try await session.respond(
                to: prompt,
                schema: generationSchema,
                options: options
            ).content
            
            // 8. 从 GeneratedContent 里解析出结果（嵌套对象）
            let selectedPlanContent = try generated.value(
                GeneratedContent.self,
                forProperty: "selectedPlan"
            )
            
            let selectedId = try selectedPlanContent.value(String.self, forProperty: "id")
            let selectedName = try selectedPlanContent.value(String.self, forProperty: "name")
            let selectedPages = try selectedPlanContent.value(Int.self, forProperty: "pagesIncluded")
            let selectedRecurring = try selectedPlanContent.value(Bool.self, forProperty: "recurring")
            
            let priceContent = try selectedPlanContent.value(
                GeneratedContent.self,
                forProperty: "price"
            )
            let amount = try priceContent.value(Double.self, forProperty: "amount")
            let currency = try priceContent.value(String.self, forProperty: "currency")
            
            // 把模型输出的 selectedPlan 映射回后端 plan（主要靠 id）
            let selectedFromBackend = backendPlans.first(where: { $0.id == selectedId }) ??
            BackendFaxPlan(
                id: selectedId,
                name: selectedName,
                pagesIncluded: selectedPages,
                recurring: selectedRecurring,
                price: amount,
                currency: currency
            )
            
            // 备选 plan ids（可能为空）
            let alternativeIds: [String] = (try? generated.value(
                [String].self,
                forProperty: "alternativePlanIds"
            )) ?? []
            
            let alternativePlans = alternativeIds.compactMap { id in
                backendPlans.first(where: { $0.id == id })
            }
            
            let explanation = try generated.value(String.self, forProperty: "explanation")
            
            self.result = PlanRecommendationResult(
                selected: selectedFromBackend,
                alternatives: alternativePlans,
                explanation: explanation
            )
            self.rawGeneratedDebug = generated.debugDescription.description
            
        } catch {
            self.errorMessage = "生成失败：\(error.localizedDescription)"
        }
        
        isRunning = false
    }
}

// MARK: - Availability 描述小工具（和之前 Demo 一样）

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
