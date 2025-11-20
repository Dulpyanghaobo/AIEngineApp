//
//  TranslateLanguageOption.swift
//  AIEngineApp
//
//  Created by i564407 on 11/17/25.
//


import Foundation

enum TranslateLanguageOption: String, CaseIterable, Identifiable {
    case englishUS
    case simplifiedChinese
    case traditionalChinese
    case spanish
    case german
    case french
    case japanese
    case korean
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .englishUS:         return "English (US)"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese:return "繁體中文"
        case .spanish:           return "Español"
        case .german:            return "Deutsch"
        case .french:            return "Français"
        case .japanese:          return "日本語"
        case .korean:            return "한국어"
        }
    }
    
    /// 给 Apple 模型看的语言描述
    var targetDescription: String {
        switch self {
        case .englishUS:
            return "American English"
        case .simplifiedChinese:
            return "Simplified Chinese"
        case .traditionalChinese:
            return "Traditional Chinese"
        case .spanish:
            return "Spanish"
        case .german:
            return "German"
        case .french:
            return "French"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        }
    }
}
