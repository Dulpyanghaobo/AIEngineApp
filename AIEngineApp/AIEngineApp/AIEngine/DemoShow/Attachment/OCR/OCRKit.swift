import Foundation
import CoreGraphics

/// 一切调用从这里开始。
public enum OCRKit {
    
    // MARK: – Private helpers
    /// 根据请求的 `outputFormat` 选取默认 formatter。
    private static func defaultFormatter(for format: OCROutputFormat) -> OCRFormatter {
        switch format {
        case .plainText:      return TXTFormatter()
        case .searchablePDF:  return SearchablePDFFormatter()
        }
    }
    
    // MARK: – Convenience API
    /// 单张图片 → 纯文本（简体中文+英文，自动检测）。
    public static func recognizeText(
        in image: CGImage,
        languages: [OCRLanguage] = [.chineseSimplified, .english, .japanese, .chineseTraditional],
        region: CGRect? = nil,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> String {
        let req = OCRRequest(images: [image],
                             languages: languages,
                             regionOfInterest: region,
                             outputFormat: .plainText)
        let res = try await process(req) { prog in       // ‼️ 把内部整体进度透传出来
            onProgress?(prog.overall)                    // 0‥1
        }
        return res.texts.first ?? ""
    }
    
    /// 多张图片 → 可搜索 PDF
    public static func generateSearchablePDF(
        from images: [CGImage],
        languages: [OCRLanguage] = [.chineseSimplified, .english],
        region: CGRect? = nil,
        onProgress: OCRBatchProcessor.ProgressHandler? = nil
    ) async throws -> Data {
        let req = OCRRequest(images: images,
                             languages: languages,
                             regionOfInterest: region,
                             outputFormat: .searchablePDF)
        let res = try await process(req, onProgress: onProgress)
        guard let data = res.pdfData else {
            throw NSError(domain: "OCRKit", code: -99,
                          userInfo: [NSLocalizedDescriptionKey: "Searchable PDF generation failed"])
        }
        return data
    }
    
    // MARK: – Full power API
    /// 完整入口：可自定义引擎 / 格式化器 / 进度回调。
    public static func process(
        _ request: OCRRequest,
        onProgress: OCRBatchProcessor.ProgressHandler? = nil,
        engine: OCREngine = VisionOCREngine(),
        formatter: OCRFormatter? = nil
    ) async throws -> OCRResult {
        let fmt = formatter ?? defaultFormatter(for: request.outputFormat)
        let processor = OCRBatchProcessor(engine: engine, formatter: fmt)
        return try await processor.process(request, onProgress: onProgress)
    }
}
