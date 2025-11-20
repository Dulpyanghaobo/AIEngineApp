//
//  TXTFormatter.swift
//  CamScanner
//
//  Created by i564407 on 2025/7/20.
//
public struct TXTFormatter: OCRFormatter {
    public init() {}

    public func generate(from pages: [PageRecognizedText]) throws -> OCRResult {
        let plain = pages.map(\.fullText)
        return OCRResult(texts: plain, pdfData: nil, metadata: nil)
    }
}
