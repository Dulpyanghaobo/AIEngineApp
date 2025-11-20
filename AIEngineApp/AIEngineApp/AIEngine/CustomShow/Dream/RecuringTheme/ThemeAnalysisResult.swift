//
//  ThemeAnalysisResult.swift
//  AIEngineApp
//
//  Created by i564407 on 10/3/25.
//


import Foundation
import FoundationModels

/// 用于表示单个重复主题及其出现次数的结构体
@Generable
struct ThemeAnalysisResult: Equatable, Codable {
    @Guide(description: "A recurring theme or symbol found in the dreams, for example '水' or '考试'.")
    var theme: String
    
    @Guide(description: "The number of times this theme has appeared.")
    var count: Int
}
