//
//  OCROutputFormat.swift
//  CamScanner
//
//  Created by i564407 on 2025/7/20.
//
public enum OCROutputFormat: String, Codable, CaseIterable, Equatable, Sendable {
    /// 纯文本（UTF‑8 `.txt`）
    case plainText = "txt"
    /// 可搜索的 PDF（嵌入文本层）
    case searchablePDF = "pdf"
}
