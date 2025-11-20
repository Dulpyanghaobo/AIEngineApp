//
//  DreamSymbolLookupTool.swift
//  AIEngineApp
//
//  Created by i564407 on 10/3/25.
//


import Foundation
import FoundationModels
import Combine

struct DreamSymbolLookupTool: Tool {
    
    // 1. 定义输入参数：只需要一个'symbol'字符串
    @Generable
    struct Arguments {
        @Guide(description: "A common dream symbol to look up, for example '牙齿', '坠落', or '水'.")
        var symbol: String
    }
    
    // 2. 定义输出类型为我们刚刚创建的 SymbolMeaning 结构体
    typealias Output = SymbolMeaning

    // 3. 工具的名称和描述
    let name = "getDreamSymbolMeaning"
    let description = "Looks up the common psychological and cultural meanings of a specific dream symbol. Use this when a user mentions a common symbol."

    // 4. 实现核心调用逻辑
    func call(arguments: Arguments) async throws -> Output {
        let symbol = arguments.symbol
        print("🤖 Tool 'getDreamSymbolMeaning' was called for symbol: \(symbol)")
        
        // 从我们的 Mock 数据库中查询含义
        let interpretations = MockSymbolDatabase.getMeaning(for: symbol)
        
        print("✅ Tool found \(interpretations.count) interpretations.")
        
        // 无论是否找到，都返回一个 SymbolMeaning 对象
        // 如果 interpretations 为空，模型需要根据指令判断如何回应
        return SymbolMeaning(symbol: symbol, interpretations: interpretations)
    }
}
