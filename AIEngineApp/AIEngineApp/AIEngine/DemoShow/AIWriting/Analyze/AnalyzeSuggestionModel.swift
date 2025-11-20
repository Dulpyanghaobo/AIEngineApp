//
//  AnalyzeSuggestionModel.swift
//  AIEngineApp
//
//  Created by i564407 on 11/17/25.
//


import Foundation
import FoundationModels

@Generable
struct AnalyzeSuggestionModel: Codable {
    var originalSentence: String
    var suggestedSentence: String
}

@Generable
struct AnalyzeResultModel: Codable {
    var suggestions: [AnalyzeSuggestionModel]
}
