import Foundation
import FoundationModels

struct FetchDreamHistoryTool: Tool {

    // 1. 定义模型调用此工具时需要提供的参数结构
    // 同样使用 @Generable，让模型知道如何构建这些参数
    @Generable
    struct Arguments {
        @Guide(description: "The keyword to search for in the dream diary. For example, '飞行' or '考试'.")
        var keyword: String?

        @Guide(description: "A string representing the time period. Supported values are 'last_three_years'.")
        var period: String?
    }
    
    // 2. 定义工具的输出类型
    // 我们希望工具返回一个梦境条目的数组
    typealias Output = [DreamEntry]

    // 3. 工具的描述，告诉模型这个工具是做什么的
    let name = "fetchDreamHistory"
    let description = "Searches the user's dream diary based on a keyword and/or a time period. Returns a list of matching dream entries."

    // 4. 实现 call 方法，这是工具的核心逻辑
    func call(arguments: Arguments) async throws -> Output {
        print("🤖 Tool 'fetchDreamHistory' was called with arguments:")
        print("   - Keyword: \(arguments.keyword ?? "nil")")
        print("   - Period: \(arguments.period ?? "nil")")
        
        // 调用我们的 Mock 数据库进行查询
        let results = MockDreamDatabase.search(
            keyword: arguments.keyword,
            period: arguments.period
        )
        
        print("✅ Tool found \(results.count) matching dreams.")
        print("results: \(results)")
        // 返回查询结果
        return results
    }
}
