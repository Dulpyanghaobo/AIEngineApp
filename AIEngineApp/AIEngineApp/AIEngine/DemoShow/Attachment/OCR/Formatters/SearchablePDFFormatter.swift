import Foundation
import CoreGraphics
#if canImport(PDFKit)
import PDFKit
#endif

#if os(iOS)
import UIKit
private typealias OSImage = UIImage
#elseif os(macOS)
import AppKit
private typealias OSImage = NSImage
#endif

/// 将每页图像 + 文本写入可搜索 PDF
public struct SearchablePDFFormatter: OCRFormatter {
    private let dpi: CGFloat = 300
    public init() {}

    public func generate(from pages: [PageRecognizedText]) throws -> OCRResult {
        #if !canImport(PDFKit)
        throw NSError(domain: "OCRKit", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "PDFKit unavailable on this platform"])
        #else
        let pdf = PDFDocument()
        for page in pages {
            // 1. 创建空白 A4 位图
            let a4Size = CGSize(width: 8.27 * dpi, height: 11.69 * dpi)
            let cg = blankImage(size: a4Size)
            #if os(iOS)
            let osImg = OSImage(cgImage: cg)
            #elseif os(macOS)
            let osImg = OSImage(cgImage: cg, size: a4Size)
            #endif
            guard let pdfPage = PDFPage(image: osImg) else { continue }
            pdf.insert(pdfPage, at: page.index)

            // 2. 隐藏文本层（FreeText 注释）
            let bounds = pdfPage.bounds(for: PDFDisplayBox.mediaBox)
            let annotation = PDFAnnotation(bounds: bounds,
                                            forType: .freeText,
                                            withProperties: nil)
            annotation.contents = page.fullText
            #if os(iOS)
            annotation.font  = UIFont.systemFont(ofSize: 0.1)
            annotation.color = UIColor.clear
            #elseif os(macOS)
            annotation.font  = NSFont.systemFont(ofSize: 0.1)
            annotation.color = NSColor.clear
            #endif
            pdfPage.addAnnotation(annotation)
        }
        guard let data = pdf.dataRepresentation() else {
            throw NSError(domain: "OCRKit", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to export PDF data"])
        }
        return OCRResult(texts: pages.map(\ .fullText),
                         pdfData: data,
                         metadata: nil)
        #endif
    }

    // MARK: - Helpers
    private func blankImage(size: CGSize) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil,
                            width: Int(size.width),
                            height: Int(size.height),
                            bitsPerComponent: 8,
                            bytesPerRow: 0,
                            space: cs,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        return ctx.makeImage()!
    }
}
