//
//  OCRTool.swift
//  AIEngineApp
//
//  Created by i564407 on 11/19/25.
//

import Foundation
import UIKit
import FoundationModels

struct OCRTool: Tool {
    let name = "performOCR"
    let description = "Runs on-device OCR on a local image file and returns extracted text."

    @Generable
    struct Arguments: ConvertibleFromGeneratedContent {
        /// 本地图片文件的路径（例如 /var/.../ocr-xxx.jpg）
        @Guide(description: "Local file path of the image to OCR")
        var imageId: String
    }

    @Generable
    struct Result: PromptRepresentable {
        var extractedText: String
    }

    func call(arguments: Arguments) async throws -> Result {
        let url = URL(fileURLWithPath: arguments.imageId)

        guard let uiImage = UIImage(contentsOfFile: url.path),
              let cgImage = uiImage.cgImage else {
            throw NSError(
                domain: "OCRTool",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "无法加载图片或获取 CGImage。"]
            )
        }

        // 使用你封装好的 OCRKit 做识别
        let text = try await OCRKit.recognizeText(in: cgImage)

        return Result(extractedText: text)
    }
}
