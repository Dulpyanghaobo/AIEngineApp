//
//  OCRFormatter.swift
//  CamScanner
//
//  Created by i564407 on 2025/7/20.
//
/// 结果格式化协议 —— 文本层 → 最终文件/内存数据
public protocol OCRFormatter: Sendable {
    /// - Parameter pages: 按页顺序的文本 & 区域坐标
    /// - Returns: `OCRResult` 含 `.texts` / `.pdfData`
    func generate(from pages: [PageRecognizedText]) throws -> OCRResult
}
