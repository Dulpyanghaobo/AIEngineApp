//
//  SymbolMeaning.swift
//  AIEngineApp
//
//  Created by i564407 on 10/3/25.
//


import Foundation
import FoundationModels

/// 用于封装梦境符号及其多种解释的结构体
@Generable
struct SymbolMeaning: Equatable, Codable {
    @Guide(description: "The dream symbol that was looked up, for example '蛇'.")
    var symbol: String
    
    @Guide(description: "A list of possible interpretations for the symbol from psychological or cultural perspectives.")
    var interpretations: [String]
}