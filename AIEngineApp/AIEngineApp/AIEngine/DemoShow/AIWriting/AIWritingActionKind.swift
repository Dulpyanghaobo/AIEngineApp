//
//  AIWritingActionKind.swift
//  AIEngineApp
//
//  Created by i564407 on 11/17/25.
//


import SwiftUI

enum AIWritingActionKind: CaseIterable, Identifiable {
    case enhanceWriting
    case changeTone
    case makeShorter
    case makeLonger
    case makeBulletedList
    case analyzeText
    case translate
    
    var id: String { title }
    
    var title: String {
        switch self {
        case .enhanceWriting: return "Enhance Writing"
        case .changeTone: return "Change Tone"
        case .makeShorter: return "Make Shorter"
        case .makeLonger: return "Make Longer"
        case .makeBulletedList: return "Make Bulleted List"
        case .analyzeText: return "Analyze Text"
        case .translate: return "Translate"
        }
    }
    
    var subtitle: String {
        switch self {
        case .enhanceWriting:
            return "Improve clarity, grammar, and style."
        case .changeTone:
            return "Adjust tone to professional, personable, or constructive."
        case .makeShorter:
            return "Convey the same message more concisely."
        case .makeLonger:
            return "Add details and explanation."
        case .makeBulletedList:
            return "Turn text into an easy-to-read list."
        case .analyzeText:
            return "Scan for biased or harmful language."
        case .translate:
            return "Translate to another language."
        }
    }
    
    var symbolName: String {
        switch self {
        case .enhanceWriting: return "wand.and.stars"
        case .changeTone: return "theatermasks"
        case .makeShorter: return "text.badge.minus"
        case .makeLonger: return "text.badge.plus"
        case .makeBulletedList: return "list.bullet"
        case .analyzeText: return "chart.bar.xaxis"
        case .translate: return "character.bubble"
        }
    }
    
    /// 用于 UI 菜单的双层数组分组
    static let menuGroups: [[AIWritingActionKind]] = [
        // 第 1 行：基础操作 + 分析
        [.enhanceWriting, .makeShorter, .makeLonger, .makeBulletedList, .analyzeText],
        // 第 2 行：二级菜单入口
        [.changeTone, .translate]
    ]
}
