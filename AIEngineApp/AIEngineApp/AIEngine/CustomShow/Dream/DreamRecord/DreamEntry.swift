import Foundation
import FoundationModels

@Generable
struct DreamEntry: Identifiable, Codable, Equatable {
    // 修复 1: 将 UUID 类型改为 String
    var id: String = UUID().uuidString
    
    // 修复 2: 将 Date 类型改为 String，并使用 ISO 8601 格式
    var date: String
    
    var title: String
    @Guide(description: "A detailed summary of the dream content.")
    var summary: String
    var keywords: [String]

    // 这是一个自定义的初始化方法，方便在创建时直接传入 Date 对象
    init(date: Date, title: String, summary: String, keywords: [String]) {
        self.date = date.ISO8601Format() // 使用 ISO 8601 格式化日期
        self.title = title
        self.summary = summary
        self.keywords = keywords
    }

    // 为了在UI中方便预览，我们需要先将日期字符串解析回 Date 对象
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let dateObject = formatter.date(from: date) {
            return dateObject.formatted(date: .long, time: .complete)
        }
        return "未知日期"
    }
}
