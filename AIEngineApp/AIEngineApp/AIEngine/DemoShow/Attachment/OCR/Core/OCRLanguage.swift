//
//  OCRLanguage.swift
//  CamScanner
//
//  Created by i564407 on 2025/7/20.
//


public enum OCRLanguage: String, Codable, CaseIterable, Equatable, Sendable {
    case english            = "en-US"
    case chineseSimplified  = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese           = "ja-JP"
    // 👉 后续追加更多 ISO‑639‑1 语言码
}
