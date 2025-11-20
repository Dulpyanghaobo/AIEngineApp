//
//  FaxQuoteTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//

import FoundationModels
// MARK: - Fax Quote Tool --------------------------------------------------

struct FaxQuoteTool: Tool {
    typealias Arguments = FaxQuoteTool.ArgumentsPayload
    typealias Output    = FaxQuoteTool.ResultPayload
    
    let name = "estimateFaxQuote"
    let description = "Estimate fax page credits and whether the user can send for free based on destination country and page count."
    
    /// 你的计价上下文，可以从 UserDefaults / 数据库 / 后端同步
    struct PricingContext: Sendable {
        let freePages: Int              // 当前用户剩余免费页
        let domesticPerPageCredits: Int // US → US
        let intlPerPageCredits: Int     // US → 非 US
    }
    
    let pricing: PricingContext
    
    // Tool Arguments：模型会自动填充这些字段
    @Generable(description: "Arguments for estimating fax cost")
    struct ArgumentsPayload: ConvertibleFromGeneratedContent {
        @Guide(description: "Destination country code, e.g. US, CA, CN")
        var destinationCountryCode: String
        
        @Guide(description: "Total number of pages in this fax", .range(1...200))
        var pages: Int
        
        @Guide(description: "Whether the fax is color (uses more credits)")
        var isColor: Bool
        
        @Guide(description: "Optional note about the document type, e.g. 'tax return', 'medical form'")
        var documentTypeHint: String?
    }
    
    // Tool Output：使用 @Generable 让模型能继续理解 & 推理
    @Generable(description: "Result of fax cost estimation for this user")
    struct ResultPayload: PromptRepresentable {
        var pages: Int
        var destinationCountryCode: String
        var totalCredits: Int
        var usesFreePagesOnly: Bool
        var estimatedUSD: Double
        var isInternational: Bool
        var explanation: String
    }
    
    func call(arguments: ArgumentsPayload) async throws -> ResultPayload {
        // 简单规则：US → US 用 domestic 单价，否则用 intl 单价
        let isDomestic = arguments.destinationCountryCode.uppercased() == "US"
        let perPageBase = isDomestic ? pricing.domesticPerPageCredits : pricing.intlPerPageCredits
        
        // 彩色页加倍消耗
        let perPage = arguments.isColor ? perPageBase * 2 : perPageBase
        let totalCredits = perPage * arguments.pages
        
        let usesFree = totalCredits <= pricing.freePages
        let isInternational = !isDomestic
        
        // 简单估价：1 credit = $0.05（你可以换成真实价格）
        let estimatedUSD = Double(totalCredits) * 0.05
        
        var explanationParts: [String] = []
        explanationParts.append("Destination: \(arguments.destinationCountryCode.uppercased()).")
        explanationParts.append("Pages: \(arguments.pages) (\(arguments.isColor ? "color" : "black & white")).")
        explanationParts.append("Per-page credits: \(perPage). Total credits: \(totalCredits).")
        
        if usesFree {
            explanationParts.append("This fits within the user's free page balance (\(pricing.freePages) credits).")
        } else {
            explanationParts.append("This exceeds the user's free page balance (\(pricing.freePages) credits).")
        }
        
        if let hint = arguments.documentTypeHint, !hint.isEmpty {
            explanationParts.append("Document type hint: \(hint).")
        }
        
        return ResultPayload(
            pages: arguments.pages,
            destinationCountryCode: arguments.destinationCountryCode.uppercased(),
            totalCredits: totalCredits,
            usesFreePagesOnly: usesFree,
            estimatedUSD: estimatedUSD,
            isInternational: isInternational,
            explanation: explanationParts.joined(separator: " ")
        )
    }
}
