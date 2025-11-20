//
//  PageRecognizedText.swift
//  CamScanner
//
//  Created by i564407 on 2025/7/20.
//
import CoreGraphics

/// Engine → Formatter 中间态
public struct PageRecognizedText: Sendable, Equatable {
    let index: Int
    let fullText: String
    let boundingBoxes: [CGRect]

    // 明确实现，避免偶发 synthesis 失败
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.index == rhs.index &&
        lhs.fullText == rhs.fullText &&
        lhs.boundingBoxes == rhs.boundingBoxes
    }
}
