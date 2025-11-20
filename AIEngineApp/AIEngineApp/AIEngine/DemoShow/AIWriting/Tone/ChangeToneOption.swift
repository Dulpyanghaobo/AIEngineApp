//
//  ChangeToneOption.swift
//  AIEngineApp
//
//  Created by i564407 on 11/17/25.
//


import Foundation

enum ChangeToneOption: String, CaseIterable, Identifiable {
    case moreProfessional
    case moreFriendly
    case moreConfident
    case moreApologetic
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .moreProfessional: return "More professional"
        case .moreFriendly:     return "More friendly"
        case .moreConfident:    return "More confident"
        case .moreApologetic:   return "More apologetic"
        }
    }
    
    /// 用于 prompt 的描述文字
    var promptInstruction: String {
        switch self {
        case .moreProfessional:
            return "Make the tone more professional while staying polite and concise."
        case .moreFriendly:
            return "Make the tone more friendly and conversational, while staying respectful."
        case .moreConfident:
            return "Make the tone more confident and assertive without being rude."
        case .moreApologetic:
            return "Make the tone more apologetic and empathetic while keeping it professional."
        }
    }
}
