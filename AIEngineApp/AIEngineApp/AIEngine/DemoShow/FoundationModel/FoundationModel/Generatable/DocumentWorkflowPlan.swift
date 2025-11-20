import SwiftUI
import Foundation
import FoundationModels

@Generable(description: "AI workflow plan for a scanned / faxed document.")
struct DocumentWorkflowPlan {
    
    // 文档层面的整体判断 -----------------------------------------
    
    @Guide(description: "Short title for this document, like 'IRS 1040 Tax Return' or 'Employment Contract'.")
    var title: String
    
    @Guide(
        description: "The main type of this document.",
        .anyOf([
            "Tax form",
            "Government form",
            "Medical record",
            "Legal contract",
            "Invoice",
            "Bank statement",
            "ID document",
            "Other"
        ])
    )
    var documentType: String
    
    @Guide(description: "One sentence describing the purpose of the document.")
    var purposeSummary: String
    
    @Guide(description: "Whether this document likely contains sensitive personal information (PII, health, financial).")
    var containsSensitiveData: Bool
    
    /// 紧急程度：1 = 不急，只是存档；5 = 非常紧急，需要尽快处理 / 发送
    @Guide(description: "Urgency score from 1 (not urgent) to 5 (very urgent).", .range(1...5))
    var urgencyScore: Int
    
    // 扫描相关建议 ---------------------------------------------------
    
    @Guide(description: "Recommended scan color mode, like 'Color', 'Grayscale', or 'Black & White'.")
    var recommendedColorMode: String
    
    @Guide(description: "Recommended DPI resolution, like 150, 300, or 600.")
    var recommendedDPI: Int
    
    @Guide(description: "Whether to aggressively compress the PDF to reduce file size.")
    var shouldCompressPDF: Bool
    
    // 传真相关建议 ---------------------------------------------------
    
    @Guide(description: "Whether this document is suitable to be sent by fax.")
    var suitableForFax: Bool
    
    @Guide(description: "Estimated number of pages when faxed, based on the description / OCR text.", .range(1...50))
    var estimatedFaxPages: Int
    
    @Guide(description: "Whether the user should add a fax cover page with notes or disclaimers.")
    var shouldAddFaxCover: Bool
    
    // 后续行动建议列表 -----------------------------------------------
    
    @Guide(
        description: "A short list of recommended next actions for the user.",
        .maximumCount(5)
    )
    var nextActions: [NextAction]
    
    // 内嵌子类型：用 String 做 identifier，避免 GenerationID 约束问题
    @Generable(description: "One actionable step in the workflow.")
    struct NextAction: Equatable {
        /// 稳定标识符，可以是 'save_to_cloud' / 'send_fax' / 'encrypt_pdf' 之类
        @Guide(description: "Stable identifier for this action, like 'send_fax' or 'save_to_cloud'.")
        var identifier: String
        
        @Guide(description: "Short label for this action, like 'Encrypt and save to JetVault'.")
        var title: String
        
        @Guide(description: "One sentence explaining why the user should do this.")
        var rationale: String
    }
}
