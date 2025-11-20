//
//  OCRRequest 2.swift
//  CamScanner
//
//  Created by i564407 on 2025/7/20.
//
import Foundation

public struct OCRResult: Sendable, Equatable {
    /// 每页识别到的纯文本（与 `images` 顺序一致）
    public let texts: [String]
    /// 若请求为 searchablePDF，则此处为生成好的 PDF 数据
    public let pdfData: Data?
    /// 额外信息（例如运行时 / 版本），供上层记录
    public let metadata: [String: String]?
}
