//
//  OCRRequest.swift
//  CamScanner
//
//  Created by i564407 on 2025/7/20.
//
import CoreGraphics

public struct OCRRequest: Sendable, Equatable {
    /// 待识别的页面序列；支持单页 / 多页
    public let images: [CGImage]
    /// 识别语言优先级；Vision 会自动 fallback
    public let languages: [OCRLanguage]
    /// 可选：仅识别该矩形区域（坐标系以左下角为原点）
    public let regionOfInterest: CGRect?
    /// 期望输出格式
    public let outputFormat: OCROutputFormat

    public init(images: [CGImage],
                languages: [OCRLanguage],
                regionOfInterest: CGRect? = nil,
                outputFormat: OCROutputFormat = .plainText) {
        precondition(!images.isEmpty, "images must not be empty")
        self.images = images
        self.languages = languages
        self.regionOfInterest = regionOfInterest
        self.outputFormat = outputFormat
    }
}
