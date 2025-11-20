import Foundation

/// 单页文本
public struct AttachmentPage: Identifiable, Hashable {
    public let id = UUID()
    public let index: Int           // 从 1 开始
    public let text: String
    
    public var title: String {
        "Page \(index)"
    }
}

/// 整份文档（包含分页）
public struct AttachmentDocument {
    public let name: String
    public let fullText: String
    public let pages: [AttachmentPage]
}

/// AI 处理范围：整份文档 / 单页
public enum AIAttachmentScope: String, CaseIterable, Identifiable {
    case wholeDocument
    case singlePage
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .wholeDocument: return "整份文档"
        case .singlePage:    return "按页处理"
        }
    }
}
