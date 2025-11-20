//
//  AnalyzeRecurringThemesTool.swift
//  AIEngineApp
//
//  Created by i564407 on 10/3/25.
//


import Foundation
import FoundationModels

struct AnalyzeRecurringThemesTool: Tool {
    
    // 1. 定义工具的输入参数
    @Generable
    struct Arguments {
        @Guide(description: "The time period to analyze. Supported values are 'last_month' and 'last_three_years'.")
        var period: String
    }
    
    // 2. 定义工具的输出类型为一个结果数组
    typealias Output = [ThemeAnalysisResult]

    // 3. 定义工具的名称和描述
    let name = "analyzeRecurringThemes"
    let description = "Analyzes the user's dream diary within a given period to find and count recurring themes or keywords."

    // 4. 实现工具的核心逻辑
    func call(arguments: Arguments) async throws -> Output {
        print("🤖 Tool 'analyzeRecurringThemes' was called with period: \(arguments.period)")
        
        // 复用 MockDreamDatabase 的查询功能来获取指定时间段的梦境
        let dreamsInPeriod = MockDreamDatabase.search(keyword: nil, period: arguments.period)
        
        // 使用字典来统计所有关键词的频率
        var themeCounts: [String: Int] = [:]
        for dream in dreamsInPeriod {
            for keyword in dream.keywords {
                themeCounts[keyword, default: 0] += 1
            }
        }
        
        // 将统计结果字典转换为 [ThemeAnalysisResult] 数组
        let analysisResults = themeCounts.map { (theme, count) in
            ThemeAnalysisResult(theme: theme, count: count)
        }
        
        // 按出现次数从高到低排序
        let sortedResults = analysisResults.sorted { $0.count > $1.count }
        
        print("✅ Tool analyzed \(dreamsInPeriod.count) dreams and found \(sortedResults.count) unique themes.")
        return sortedResults
    }
}
