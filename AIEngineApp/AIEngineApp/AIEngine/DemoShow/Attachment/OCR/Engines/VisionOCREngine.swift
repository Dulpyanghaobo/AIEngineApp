import Vision
import CoreGraphics
import Foundation

#if canImport(UIKit) // macOS Catalyst 亦可
import UIKit.UIImage  // 仅供调试 & 便捷扩展
#endif

public final class VisionOCREngine: OCREngine {
    private let revision: Int
    private let level: VNRequestTextRecognitionLevel
    private let usesLanguageCorrection: Bool
    
    /// - Parameters:
    ///   - revision: Vision 版本，默认用最新 Revision 3（iOS 17/macOS 14）。
    ///   - level: `.accurate` or `.fast`。
    ///   - languageCorrection: 拼写纠正。
    public init(revision: Int = VNRecognizeTextRequestRevision3,
                level: VNRequestTextRecognitionLevel = .accurate,
                languageCorrection: Bool = true) {
        self.revision = revision
        self.level = level
        self.usesLanguageCorrection = languageCorrection
    }
    
    // MARK: - OCREngine
    public func recognize(_ request: OCRRequest,
                          progress: @escaping (Double) -> Void) async throws -> [PageRecognizedText] {
        try Task.checkCancellation()

        var pages: [PageRecognizedText] = []
        let total = Double(request.images.count)

        for (idx, cgImage) in request.images.enumerated() {
            try Task.checkCancellation()

            // ‼️ ① 先播一帧 0，确保 HUD 从 0% 开始
            if idx == 0 { progress(0) }

            let pageText = try await recognizeSinglePage(
                cgImage: cgImage,
                roi: request.regionOfInterest,
                languages: request.languages
            ) { pageFrac in
                let global = (Double(idx) + pageFrac) / total
                progress(global)                      // 0‥1
            }

            pages.append(PageRecognizedText(index: idx,
                                            fullText: pageText.text,
                                            boundingBoxes: pageText.boxes))
        }

        progress(1)
        return pages
    }

    
    // MARK: - Private helpers
    private func recognizeSinglePage(cgImage: CGImage,
                                     roi: CGRect?,
                                     languages: [OCRLanguage], onProgress: @escaping (Double) -> Void) async throws -> (text: String, boxes: [CGRect]) {
        return try await withCheckedThrowingContinuation { cont in
            // 1. 创建请求
            let req = VNRecognizeTextRequest { req, err in
                if let err { return cont.resume(throwing: err) }
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    return cont.resume(returning: ("", []))
                }
                // 2. 拼接文本 & 取坐标
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let full = lines.joined(separator: "\n")
                let bboxes = observations.map { obs -> CGRect in
                    // Vision 坐标系 (0,0)=左下 → 转 CGImage 坐标
                    let boundingBox = obs.boundingBox
                    return VNImageRectForNormalizedRect(boundingBox,
                                                        Int(cgImage.width),
                                                        Int(cgImage.height))
                }
                cont.resume(returning: (full, bboxes))
            }
            req.revision = revision
            req.recognitionLevel = level
            req.usesLanguageCorrection = usesLanguageCorrection
            req.recognitionLanguages = languages.map(\ .rawValue)
            if let roi {
                req.regionOfInterest = roi
            }
            req.progressHandler = { _, frac, _ in
                onProgress(frac)                       // 0‥1
            }
            // 3. Handler
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([req])
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}
